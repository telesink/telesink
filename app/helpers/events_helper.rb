module EventsHelper
  PROPERTY_SUMMARY_LIMIT = 3

  def highlighted_event_body(event, column, length: 87)
    text = event.text
    if column.single_event_type?
      length = 101
    end

    if column&.search_term.present?
      truncated = truncate(text, length: length, omission: "…")

      highlight(
        truncated,
        column.search_term,
        highlighter: '<mark class="event-preview__highlight">\1</mark>'
      )
    else
      truncate(text, length: length, omission: "…")
    end
  end

  def day_delimiter_label(occurred_at)
    date = occurred_at.to_date

    if date == Date.today
      "Today"
    elsif date == Date.yesterday
      "Yesterday"
    else
      occurred_at.strftime("%A, %B %d, %Y")
    end
  end

  TOO_LONG = 120

  def long_property?(value)
    str = property_full(value).to_s.strip
    return false if str.blank?

    str.length > TOO_LONG
  end

  def property_teaser(value)
    return if value.nil?

    str = property_full(value)
    str.length > TOO_LONG ? str[0...(TOO_LONG-1)] + "…" : str
  end

  def property_full(value)
    return if value.nil?

    case value
    when Hash, Array
      value.to_json
    else
      value.to_s
    end
  end

  def property_filterable?(value)
    Event.property_filter_value(value).present? || value == false
  end

  def property_filter_value(value)
    Event.property_filter_value(value)
  end

  def property_numeric_filterable?(value)
    Event.property_numeric_filter_value(value).present?
  end

  def property_numeric_filter_value(value)
    Event.property_numeric_filter_value(value)
  end

  def property_filter_label(property_key, property_op, property_value)
    return unless property_key.present?

    if property_op == "exists"
      "#{property_key} exists"
    elsif property_op == "lt" && !property_value.nil?
      "#{property_key} < #{property_value}"
    elsif property_op == "gt" && !property_value.nil?
      "#{property_key} > #{property_value}"
    elsif !property_value.nil?
      "#{property_key}=#{property_value}"
    end
  end

  def event_feed_empty_label(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    filters = []
    filters << event_type if event_type.present?
    filters << event_date.iso8601 if event_date.present?
    if search_query.present?
      filters << "\"#{truncate(search_query, length: 48, omission: "…")}\""
    end

    property_label = property_filter_label(property_key, property_op, property_value)

    if property_label.present?
      filters << truncate(property_label, length: 48, omission: "…")
    end

    if filters.any?
      "no events matching #{filters.join(" ")}"
    else
      "no events yet"
    end
  end

  def active_feed_filter?(event_type:, event_date:, property_key:, search_query:)
    event_type.present? ||
      event_date.present? ||
      property_key.present? ||
      search_query.present?
  end

  def suggested_saved_view_name(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    parts = []
    parts << event_type if event_type.present?
    parts << event_date.iso8601 if event_date.present?
    parts << "\"#{search_query}\"" if search_query.present?

    property_label = property_filter_label(property_key, property_op, property_value)
    parts << property_label if property_label.present?

    parts.join(" ")
  end

  def saved_view_current?(
    saved_view,
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    saved_view.matches_filters?(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    )
  end

  def event_property_summary(event, limit: PROPERTY_SUMMARY_LIMIT)
    return if event.properties.blank?

    pairs = event
      .properties
      .first(limit)
      .map do |key, value|
        tag.span(class: "event-row__property") do
          safe_join([
            tag.strong("#{key}: ", class: "event-row__property-key"),
            compact_property_value(value)
          ])
        end
      end

    safe_join(pairs, tag.span("·", class: "event-row__property-divider"))
  end

  def compact_property_value(value)
    case value
    when Hash, Array
      value.to_json
    else
      value.to_s
    end.squish
  end

  def event_filter_properties(event)
    return {} if event.properties.blank?

    event.properties.each_with_object({}) do |(key, value), result|
      filter_value = property_numeric_filter_value(value)
      result[key] = filter_value unless filter_value.nil?
    end
  end

  def event_search_text(event)
    parts = [ event.event_type, event.text ]

    event.properties.each do |key, value|
      parts << key
      parts << compact_property_value(value)
    end

    parts.join(" ").squish
  end

  def event_type_count_dom_id(event_type, variant:)
    Event.event_type_count_dom_id(event_type, variant: variant)
  end

  def event_type_color_class(event_type)
    "event-type-color-#{event_type.to_s.each_byte.sum % 12}"
  end
end
