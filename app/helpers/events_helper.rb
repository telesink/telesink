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

  def event_type_count_dom_id(event_type, variant:)
    Event.event_type_count_dom_id(event_type, variant: variant)
  end

  def event_type_color_class(event_type)
    "event-type-color-#{event_type.to_s.each_byte.sum % 12}"
  end
end
