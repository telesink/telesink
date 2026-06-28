require "digest"

class Event < ApplicationRecord
  FEED_BATCH_SIZE = 60
  PROPERTY_FILTER_OPS = %w[eq exists lt gt].freeze
  NUMERIC_PROPERTY_FILTER_OPS = %w[lt gt].freeze
  NUMERIC_PROPERTY_STREAM_OP = "number"
  RUBY_NUMERIC_PATTERN = /
    \A
    [+-]?
    (?:\d+(?:\.\d*)?|\.\d+)
    (?:[eE][+-]?\d+)?
    \z
  /x
  SQL_NUMERIC_PATTERN = "[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?"

  belongs_to :sink

  validates :event_type, presence: true
  validates :text, presence: true

  validates :idempotency_key,
            uniqueness: { scope: :sink_id },
            allow_nil: true,
            length: { maximum: 255 }

  scope :for_column, ->(column) {
    rel = where(sink_id: column.sink_id)

    if column.event_types.any?
      rel = rel.where(event_type: column.event_types)
    end

    if (term = column.search_term)
      rel = rel.where("text ILIKE ?", "%#{term}%")

      # Optional later: also search inside properties
      # rel = rel.or(where("properties::text ILIKE ?", "%#{term}%"))
    end

    rel.order(occurred_at: :desc, id: :desc)
  }

  def self.feed_batch(
    sink,
    limit: FEED_BATCH_SIZE,
    before_id: nil,
    event_type: nil,
    date: nil,
    property_key: nil,
    property_op: nil,
    property_value: nil,
    search_query: nil
  )
    rel = where(sink_id: sink.id)
    rel = rel.where(event_type: event_type) if event_type.present?
    rel = rel.where(occurred_at: date.all_day) if date.present?

    if (normalized_search_query = normalize_search_query(search_query))
      query = "%#{sanitize_sql_like(normalized_search_query)}%"
      rel = rel.where(
        "event_type ILIKE :query OR text ILIKE :query OR EXISTS (" \
          "SELECT 1 FROM jsonb_each_text(events.properties) " \
          "AS property_search(key, value) " \
          "WHERE property_search.key ILIKE :query " \
          "OR property_search.value ILIKE :query" \
        ")",
        query: query
      )
    end

    numeric_property_value = property_numeric_filter_value(property_value)

    if property_key.present? && property_op == "exists"
      rel = rel.where("properties ? :property_key", property_key: property_key)
    elsif property_key.present? && numeric_property_filter_op?(property_op) && numeric_property_value
      operator = property_op == "lt" ? "<" : ">"
      rel = rel.where(
        "(properties ->> :property_key) ~ :numeric_pattern AND " \
          "(properties ->> :property_key)::numeric #{operator} :property_value",
        property_key: property_key,
        numeric_pattern: "^#{SQL_NUMERIC_PATTERN}$",
        property_value: numeric_property_value
      )
    elsif property_key.present? && !property_value.nil?
      rel = rel.where("properties ->> ? = ?", property_key, property_value.to_s)
    end

    if before_id.present?
      before_event = rel.find_by(id: before_id)
      return [] unless before_event

      rel = rel.where(
        "(occurred_at, id) < (?, ?)",
        before_event.occurred_at,
        before_event.id
      )
    end

    rel.order(occurred_at: :desc, id: :desc).limit(limit).to_a.reverse
  end

  def self.feed_stream_key(
    event_type,
    date: nil,
    property_key: nil,
    property_op: nil,
    property_value: nil
  )
    parts = [
      event_type.presence || "all",
      date&.iso8601 || "live"
    ]

    if property_key.present? && property_op == "exists"
      parts << "property"
      parts << event_type_dom_key("#{property_key}:exists")
    elsif property_key.present? && numeric_property_stream_op?(property_op)
      parts << "property"
      parts << event_type_dom_key("#{property_key}:number")
    elsif property_key.present? && !property_value.nil?
      parts << "property"
      parts << event_type_dom_key("#{property_key}=#{property_value}")
    end

    parts.join(":")
  end

  def self.property_filter_value(value)
    case value
    when String
      value.presence
    when Numeric, TrueClass, FalseClass
      value.to_s
    end
  end

  def self.property_numeric_filter_value(value)
    case value
    when Numeric
      value.to_s
    when String
      stripped = value.strip
      stripped if stripped.match?(RUBY_NUMERIC_PATTERN)
    end
  end

  def self.normalize_search_query(value)
    value.to_s.strip.presence
  end

  def self.numeric_property_filter_op?(property_op)
    NUMERIC_PROPERTY_FILTER_OPS.include?(property_op)
  end

  def self.numeric_property_stream_op?(property_op)
    numeric_property_filter_op?(property_op) || property_op == NUMERIC_PROPERTY_STREAM_OP
  end

  def self.event_type_dom_key(event_type)
    Digest::SHA256.hexdigest(event_type.to_s).first(12)
  end

  def self.event_type_count_dom_id(event_type, variant:)
    if event_type.present?
      "event_type_count_#{variant}_#{event_type_dom_key(event_type)}"
    else
      "event_type_count_#{variant}_all"
    end
  end

  after_create_commit(
    :broadcast_to_feed_streams,
    :broadcast_event_type_counts,
    :mark_unread_for_all_members,
    unless: -> { Rails.env.test? }
  )

  private

  def broadcast_to_feed_streams
    event_date = occurred_at.in_time_zone.to_date

    [ nil, event_type ].each do |feed_event_type|
      [ nil, event_date ].each do |feed_date|
        Turbo::StreamsChannel.broadcast_append_to(
          sink,
          "events",
          Event.feed_stream_key(feed_event_type, date: feed_date),
          target: "events_feed",
          partial: "events/feed_row",
          locals: { event: self, new_event: true }
        )
      end
    end

    properties.each do |key, value|
      [ nil, event_type ].each do |feed_event_type|
        [ nil, event_date ].each do |feed_date|
          Turbo::StreamsChannel.broadcast_append_to(
            sink,
            "events",
            Event.feed_stream_key(
              feed_event_type,
              date: feed_date,
              property_key: key,
              property_op: "exists"
            ),
            target: "events_feed",
            partial: "events/feed_row",
            locals: { event: self, new_event: true }
          )
        end
      end

      property_value = Event.property_filter_value(value)
      numeric_property_value = Event.property_numeric_filter_value(value)

      if numeric_property_value.present?
        [ nil, event_type ].each do |feed_event_type|
          [ nil, event_date ].each do |feed_date|
            Turbo::StreamsChannel.broadcast_append_to(
              sink,
              "events",
              Event.feed_stream_key(
                feed_event_type,
                date: feed_date,
                property_key: key,
                property_op: NUMERIC_PROPERTY_STREAM_OP
              ),
              target: "events_feed",
              partial: "events/feed_row",
              locals: { event: self, new_event: true }
            )
          end
        end
      end

      next if property_value.nil?

      [ nil, event_type ].each do |feed_event_type|
        [ nil, event_date ].each do |feed_date|
          Turbo::StreamsChannel.broadcast_append_to(
            sink,
            "events",
            Event.feed_stream_key(
              feed_event_type,
              date: feed_date,
              property_key: key,
              property_op: "eq",
              property_value: property_value
            ),
            target: "events_feed",
            partial: "events/feed_row",
            locals: { event: self, new_event: true }
          )
        end
      end
    end
  end

  def broadcast_event_type_counts
    total_count = sink.events.count
    event_type_count = sink.events.where(event_type: event_type).count

    %w[desktop mobile].each do |variant|
      Turbo::StreamsChannel.broadcast_replace_to(
        sink,
        "event_type_counts",
        target: Event.event_type_count_dom_id(nil, variant: variant),
        partial: "sinks/event_filter_count",
        locals: { event_type: nil, count: total_count, variant: variant }
      )

      if event_type_count == 1
        Turbo::StreamsChannel.broadcast_append_to(
          sink,
          "event_type_counts",
          target: "event_type_filter_list_#{variant}",
          partial: "sinks/event_filter_item",
          locals: {
            sink: sink,
            event_type: event_type,
            count: event_type_count,
            current_event_type: nil,
            event_date: nil,
            variant: variant
          }
        )
      else
        Turbo::StreamsChannel.broadcast_replace_to(
          sink,
          "event_type_counts",
          target: Event.event_type_count_dom_id(event_type, variant: variant),
          partial: "sinks/event_filter_count",
          locals: {
            event_type: event_type,
            count: event_type_count,
            variant: variant
          }
        )
      end
    end
  end

  def mark_unread_for_all_members
    sink.sink_memberships.includes(:user).each do |membership|
      next if membership.user.currently_viewing?(sink)

      membership.increment_unread!

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{membership.user_id}_sinks",
        target: ActionView::RecordIdentifier.dom_id(membership.sink, "list_item"),
        partial: "sinks/sink",
        locals: {
          current_sink_id: membership.user.current_sink_id,
          sink: membership.sink,
          membership: membership,
          can_administer: membership.user.can_administer?
        }
      )
    end
  end
end
