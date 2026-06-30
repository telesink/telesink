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
  EVENT_TYPE_LABELS = {
    "add_to_cart" => "Added to cart",
    "agent_run_completed" => "Agent run completed",
    "agent_run_failed" => "Agent run failed",
    "agent_run_started" => "Agent run started",
    "alert_firing" => "Alert firing",
    "approval_requested" => "Approval requested",
    "agent_replied" => "Agent replied",
    "backup_completed" => "Backup completed",
    "browser_action" => "Browser action",
    "cart_abandoned" => "Cart abandoned",
    "checkout_started" => "Checkout started",
    "code_patch_created" => "Code patch created",
    "deploy_finished" => "Deploy finished",
    "deploy_started" => "Deploy started",
    "email_delivered" => "Email delivered",
    "evaluation_passed" => "Evaluation passed",
    "exception" => "Exception",
    "feature_flag_changed" => "Feature flag changed",
    "handoff_created" => "Handoff created",
    "incident_opened" => "Incident opened",
    "invoice_created" => "Invoice created",
    "inventory_low" => "Inventory low",
    "job" => "Job",
    "memory_retrieved" => "Memory retrieved",
    "order_created" => "Order created",
    "payment_failed" => "Payment failed",
    "payment_authorized" => "Payment authorized",
    "payment_succeeded" => "Payment succeeded",
    "plan_updated" => "Plan updated",
    "product_viewed" => "Product viewed",
    "refund_created" => "Refund created",
    "render" => "Rendered",
    "reply_waiting" => "Reply waiting",
    "retry_scheduled" => "Retry scheduled",
    "subscription_updated" => "Subscription updated",
    "ticket_created" => "Ticket created",
    "ticket_escalated" => "Ticket escalated",
    "tool_called" => "Tool called",
    "triage_completed" => "Triage completed",
    "worker_retry" => "Worker retry"
  }.freeze

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
    search_query: nil,
    time_zone: Time.zone
  )
    rel = feed_scope(
      sink,
      event_type: event_type,
      date: date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query,
      time_zone: time_zone
    )

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

  def self.feed_scope(
    sink,
    event_type: nil,
    date: nil,
    property_key: nil,
    property_op: nil,
    property_value: nil,
    search_query: nil,
    time_zone: Time.zone
  )
    property_filter = normalize_property_filter(
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      property_value_provided: !property_value.nil?
    )
    event_type = normalize_event_type(event_type)
    property_key = property_filter[:property_key]
    property_op = property_filter[:property_op]
    property_value = property_filter[:property_value]

    rel = where(sink_id: sink.id)
    rel = rel.where(event_type: event_type) if event_type.present?
    rel = rel.where(occurred_at: date_range_for(date, time_zone: time_zone)) if date.present?

    if (normalized_search_query = normalize_search_query(search_query))
      query = "%#{sanitize_sql_like(normalized_search_query)}%"
      rel = rel.where(
        "search_text ILIKE :query OR " \
          "(search_text IS NULL AND CONCAT_WS(' ', event_type, text, properties::text) ILIKE :query)",
        query:
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
      rel = rel.where("properties ->> ? = ?", property_key, normalize_utf8_string(property_value))
    end

    rel
  end

  def self.feed_stream_key(
    event_type,
    date: nil,
    property_key: nil,
    property_op: nil,
    property_value: nil
  )
    event_type = normalize_event_type(event_type)
    property_key = normalize_utf8_string(property_key).strip.presence
    property_op = normalize_utf8_string(property_op).strip.presence
    property_value = normalize_utf8_string(property_value) unless property_value.nil?

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
      normalize_utf8_string(value)
    when Numeric, TrueClass, FalseClass
      value.to_s
    end
  end

  def self.property_numeric_filter_value(value)
    case value
    when Numeric
      value.to_s
    when String
      stripped = normalize_utf8_string(value).strip
      stripped if stripped.match?(RUBY_NUMERIC_PATTERN)
    end
  end

  def self.normalize_search_query(value)
    normalize_utf8_string(value).strip.presence
  end

  def self.normalize_event_type(value)
    normalize_utf8_string(value).strip.presence
  end

  def self.event_type_label(value)
    event_type = normalize_event_type(value)
    return "" if event_type.blank?
    return event_type if event_type.match?(/\A[A-Z0-9]+\z/)

    EVENT_TYPE_LABELS[event_type] ||
      event_type.tr("_-", " ").squish.capitalize
  end

  def self.normalize_event_date(value)
    return if value.blank?
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def self.resolve_time_zone(time_zone)
    return time_zone if time_zone.is_a?(ActiveSupport::TimeZone)

    ActiveSupport::TimeZone[time_zone.to_s] || Time.zone
  end

  def self.date_range_for(date, time_zone: Time.zone)
    date.in_time_zone(resolve_time_zone(time_zone)).all_day
  end

  def self.month_range_for(month, time_zone: Time.zone)
    month.in_time_zone(resolve_time_zone(time_zone)).all_month
  end

  def self.local_date_sql(column_name = "occurred_at", time_zone: Time.zone)
    zone_name = resolve_time_zone(time_zone).tzinfo.name
    quoted_zone_name = connection.quote(zone_name)
    quoted_column_name = connection.quote_column_name(column_name)

    "DATE((#{quoted_table_name}.#{quoted_column_name} AT TIME ZONE 'UTC') " \
      "AT TIME ZONE #{quoted_zone_name})"
  end

  def self.normalize_utf8_string(value)
    string = value.to_s
    string = string.dup.force_encoding(Encoding::UTF_8) if string.encoding == Encoding::ASCII_8BIT

    string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
  end

  def self.normalize_feed_filters(source)
    property_filter = normalize_property_filter(
      property_key: feed_filter_param(source, :property_key),
      property_op: feed_filter_param(source, :property_op),
      property_value: feed_filter_param(source, :property_value),
      property_value_provided: feed_filter_param_key?(source, :property_value)
    )

    {
      event_type: normalize_event_type(feed_filter_param(source, :event_type)),
      event_date: normalize_event_date(
        feed_filter_param(source, :event_date).presence || feed_filter_param(source, :date)
      ),
      search_query: normalize_search_query(
        feed_filter_param(source, :search_query).presence || feed_filter_param(source, :q)
      ),
      property_key: property_filter[:property_key],
      property_op: property_filter[:property_op],
      property_value: property_filter[:property_value]
    }
  end

  def self.feed_filter_params(source)
    filters = normalize_feed_filters(source)
    params = {
      event_type: filters[:event_type],
      date: filters[:event_date]&.iso8601,
      q: filters[:search_query]
    }

    if filters[:property_key]
      params[:property_key] = filters[:property_key]
      params[:property_op] = filters[:property_op]
      params[:property_value] = filters[:property_value] unless filters[:property_value].nil?
    end

    params.compact
  end

  def self.feed_can_mark_viewed?(source)
    filters = normalize_feed_filters(source)

    filters[:event_type].blank? &&
      filters[:event_date].blank? &&
      filters[:search_query].blank? &&
      filters[:property_key].blank?
  end

  def self.normalize_property_filter(
    property_key:,
    property_op: nil,
    property_value: nil,
    property_value_provided: false
  )
    key = normalize_utf8_string(property_key).strip.presence
    op = normalize_utf8_string(property_op).strip.presence || "eq"
    value = normalize_utf8_string(property_value) if key && property_value_provided

    unless key && PROPERTY_FILTER_OPS.include?(op)
      return { property_key: nil, property_op: nil, property_value: nil }
    end

    if op == "eq" && value.nil?
      key = nil
      op = nil
    elsif numeric_property_filter_op?(op)
      value = property_numeric_filter_value(value)

      if value.nil?
        key = nil
        op = nil
      end
    elsif op == "exists"
      value = nil
    end

    { property_key: key, property_op: op, property_value: value }
  end

  def self.search_text_for(event)
    parts = [ event.event_type, event.text ]

    event.properties.to_h.each do |key, value|
      parts << key
      parts << searchable_property_value(value)
    end

    parts.compact.join(" ").squish
  end

  def self.numeric_property_filter_op?(property_op)
    NUMERIC_PROPERTY_FILTER_OPS.include?(property_op)
  end

  def self.numeric_property_stream_op?(property_op)
    numeric_property_filter_op?(property_op) || property_op == NUMERIC_PROPERTY_STREAM_OP
  end

  def self.event_type_dom_key(event_type)
    Digest::SHA256.hexdigest(normalize_utf8_string(event_type)).first(12)
  end

  def self.event_type_count_dom_id(event_type, variant:)
    if event_type.present?
      "event_type_count_#{variant}_#{event_type_dom_key(event_type)}"
    else
      "event_type_count_#{variant}_all"
    end
  end

  before_validation :normalize_text_attributes
  before_validation :refresh_search_text

  after_create_commit(
    :broadcast_to_feed_streams,
    :broadcast_event_type_counts,
    :mark_unread_for_all_members,
    unless: -> { Rails.env.test? }
  )

  def properties=(value)
    super(normalize_property_encodings(value || {}))
  end

  private

  def self.feed_filter_param(source, key)
    return unless source.respond_to?(:[])

    if source.respond_to?(:key?)
      return source[key] if source.key?(key)
      return source[key.to_s] if source.key?(key.to_s)
    end

    source[key]
  end

  def self.feed_filter_param_key?(source, key)
    unless source.respond_to?(:key?)
      return source.respond_to?(:[]) && !feed_filter_param(source, key).nil?
    end

    source.key?(key) || source.key?(key.to_s)
  end

  def self.searchable_property_value(value)
    case value
    when Hash, Array
      value.to_json
    else
      normalize_utf8_string(value)
    end
  end

  def refresh_search_text
    self.search_text = Event.search_text_for(self)
  end

  def normalize_text_attributes
    self.event_type = normalize_utf8_string(event_type) if event_type
    self.emoji = normalize_utf8_string(emoji) if emoji
    self.text = normalize_utf8_string(text) if text
    self.idempotency_key = normalize_utf8_string(idempotency_key) if idempotency_key
    self.sdk_name = normalize_utf8_string(sdk_name) if sdk_name
    self.sdk_version = normalize_utf8_string(sdk_version) if sdk_version
    self.properties = normalize_property_encodings(properties) if properties
  end

  def normalize_property_encodings(value)
    if value.respond_to?(:to_unsafe_h)
      value = value.to_unsafe_h
    elsif !value.is_a?(Hash) && !value.is_a?(Array) && value.respond_to?(:to_h)
      value = value.to_h
    end

    case value
    when Hash
      value.to_h.transform_keys { |key| normalize_utf8_string(key) }
        .transform_values { |property_value| normalize_property_encodings(property_value) }
    when Array
      value.map { |property_value| normalize_property_encodings(property_value) }
    when String
      normalize_utf8_string(value)
    else
      value
    end
  end

  def normalize_utf8_string(value)
    self.class.normalize_utf8_string(value)
  end

  def broadcast_to_feed_streams
    event_dates = feed_stream_dates

    [ nil, event_type ].each do |feed_event_type|
      [ nil, *event_dates ].each do |feed_date|
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
        [ nil, *event_dates ].each do |feed_date|
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
          [ nil, *event_dates ].each do |feed_date|
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
        [ nil, *event_dates ].each do |feed_date|
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
            event_icon: emoji,
            count: event_type_count,
            current_event_type: nil,
            event_date: nil,
            property_key: nil,
            property_op: nil,
            property_value: nil,
            search_query: nil,
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
      next if membership.actively_viewing_sink?

      membership.increment_unread!
    end
  end

  def feed_stream_dates
    event_date = occurred_at.utc.to_date

    [ event_date - 1, event_date, event_date + 1 ]
  end
end
