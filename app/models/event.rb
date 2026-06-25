require "digest"

class Event < ApplicationRecord
  FEED_BATCH_SIZE = 60

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

  def self.feed_batch(sink, limit: FEED_BATCH_SIZE, before_id: nil, event_type: nil)
    rel = where(sink_id: sink.id)
    rel = rel.where(event_type: event_type) if event_type.present?

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

  def self.feed_stream_key(event_type)
    event_type.present? ? event_type : "all"
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
    [ nil, event_type ].each do |feed_event_type|
      Turbo::StreamsChannel.broadcast_append_to(
        sink,
        "events",
        Event.feed_stream_key(feed_event_type),
        target: "events_feed",
        partial: "events/feed_row",
        locals: { event: self, new_event: true }
      )
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
