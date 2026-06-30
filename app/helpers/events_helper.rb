module EventsHelper
  PROPERTY_SUMMARY_LIMIT = 3
  EVENT_TYPE_COLOR_PALETTE = [
    ["var(--color-red-700)", "var(--color-red-300)"],
    ["var(--color-orange-700)", "var(--color-orange-300)"],
    ["var(--color-amber-700)", "var(--color-amber-300)"],
    ["var(--color-yellow-700)", "var(--color-yellow-300)"],
    ["var(--color-lime-700)", "var(--color-lime-300)"],
    ["var(--color-green-700)", "var(--color-green-300)"],
    ["var(--color-emerald-700)", "var(--color-emerald-300)"],
    ["var(--color-teal-700)", "var(--color-teal-300)"],
    ["var(--color-sky-700)", "var(--color-sky-300)"],
    ["var(--color-blue-700)", "var(--color-blue-300)"],
    ["var(--color-indigo-700)", "var(--color-indigo-300)"],
    ["var(--color-violet-700)", "var(--color-violet-300)"],
    ["var(--color-purple-700)", "var(--color-purple-300)"],
    ["var(--color-fuchsia-700)", "var(--color-fuchsia-300)"],
    ["var(--color-pink-700)", "var(--color-pink-300)"],
    ["var(--color-rose-700)", "var(--color-rose-300)"],
    ["var(--color-red-800)", "var(--color-red-400)"],
    ["var(--color-orange-800)", "var(--color-orange-400)"],
    ["var(--color-amber-800)", "var(--color-amber-400)"],
    ["var(--color-lime-800)", "var(--color-lime-400)"],
    ["var(--color-green-800)", "var(--color-green-400)"],
    ["var(--color-emerald-800)", "var(--color-emerald-400)"],
    ["var(--color-teal-800)", "var(--color-teal-400)"],
    ["var(--color-sky-800)", "var(--color-sky-400)"],
    ["var(--color-blue-800)", "var(--color-blue-400)"],
    ["var(--color-indigo-800)", "var(--color-indigo-400)"],
    ["var(--color-violet-800)", "var(--color-violet-400)"],
    ["var(--color-purple-800)", "var(--color-purple-400)"],
    ["var(--color-fuchsia-800)", "var(--color-fuchsia-400)"],
    ["var(--color-pink-800)", "var(--color-pink-400)"],
    ["var(--color-rose-800)", "var(--color-rose-400)"]
  ].freeze

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
    time = occurred_at.in_time_zone(browser_time_zone)
    date = time.to_date

    if date == browser_time_zone.today
      "Today"
    elsif date == browser_time_zone.yesterday
      "Yesterday"
    else
      time.strftime("%A, %B %d, %Y")
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

  def property_action_label(value)
    teaser = property_teaser(value)
    return teaser if teaser.present?

    filter_value = property_filter_value(value)
    return "empty" if filter_value.nil?

    SavedView.property_filter_value_label(filter_value)
  end

  def property_full(value)
    return "null" if value.nil?

    case value
    when Hash, Array
      value.to_json
    else
      value.to_s
    end
  end

  def property_filterable?(value)
    !Event.property_filter_value(value).nil?
  end

  def property_filter_value(value)
    Event.property_filter_value(value)
  end

  def active_property_filter_row?(key, value, property_key:, property_op:, property_value:)
    normalized_key = Event.normalize_utf8_string(key)
    normalized_property_key = Event.normalize_utf8_string(property_key)
    return false unless normalized_property_key.present? && normalized_key == normalized_property_key
    return true if property_op == "exists"

    if Event.numeric_property_filter_op?(property_op)
      numeric_value = property_numeric_filter_value(value)
      threshold = property_numeric_filter_value(property_value)
      return false unless numeric_value.present? && threshold.present?

      return numeric_value.to_f < threshold.to_f if property_op == "lt"

      return numeric_value.to_f > threshold.to_f
    end

    filter_value = property_filter_value(value)
    !filter_value.nil? && filter_value == Event.normalize_utf8_string(property_value)
  end

  def property_numeric_filterable?(value)
    Event.property_numeric_filter_value(value).present?
  end

  def property_numeric_filter_value(value)
    Event.property_numeric_filter_value(value)
  end

  def property_filter_label(property_key, property_op, property_value)
    SavedView.property_filter_label(property_key, property_op, property_value)
  end

  def feed_filter_parts(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:,
    today_label: false,
    time_zone: browser_time_zone
  )
    SavedView.filter_parts(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query,
      today_label: today_label,
      time_zone: time_zone
    )
  end

  def event_feed_empty_label(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    filters = feed_filter_parts(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    )

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

  def current_saved_view_for(
    saved_views,
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    saved_views.find do |saved_view|
      saved_view_current?(
        saved_view,
        event_type: event_type,
        event_date: event_date,
        property_key: property_key,
        property_op: property_op,
        property_value: property_value,
        search_query: search_query
      )
    end
  end

  def suggested_saved_view_name(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    feed_filter_parts(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    ).join(" ")
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

  def saved_view_filter_summary(saved_view)
    saved_view.filter_summary
  end

  def event_status_filter_links(
    event_type:,
    event_date:,
    property_key:,
    property_op:,
    property_value:,
    search_query:
  )
    links = []

    if event_type.present?
      links << {
        label: event_type_label(event_type),
        params: feed_filter_params(
          event_date: event_date,
          property_key: property_key,
          property_op: property_op,
          property_value: property_value,
          search_query: search_query
        ),
        class_name: event_type_color_class(event_type),
        style: event_type_color_style(event_type),
        title: "remove event filter"
      }
    end

    if event_date.present?
      links << {
        label: event_date == browser_time_zone.today ? "today" : event_date.iso8601,
        params: feed_filter_params(
          event_type: event_type,
          property_key: property_key,
          property_op: property_op,
          property_value: property_value,
          search_query: search_query
        ),
        title: "remove date filter"
      }
    end

    if search_query.present?
      links << {
        label: %("#{truncate(search_query, length: 48, omission: "…")}"),
        params: feed_filter_params(
          event_type: event_type,
          event_date: event_date,
          property_key: property_key,
          property_op: property_op,
          property_value: property_value
        ),
        title: "remove search"
      }
    end

    property_label = property_filter_label(property_key, property_op, property_value)

    if property_label.present?
      links << {
        label: property_label,
        params: feed_filter_params(
          event_type: event_type,
          event_date: event_date,
          search_query: search_query
        ),
        title: "remove property filter"
      }
    end

    links
  end

  def feed_filter_params(
    event_type: nil,
    event_date: nil,
    property_key: nil,
    property_op: nil,
    property_value: nil,
    search_query: nil,
    month: nil
  )
    filter_params = Event.feed_filter_params(
      event_type: event_type,
      event_date: event_date,
      property_key: property_key,
      property_op: property_op,
      property_value: property_value,
      search_query: search_query
    )

    calendar_month = normalize_calendar_month(month || current_calendar_month_param)
    filter_params[:month] = calendar_month if calendar_month.present?

    filter_params
  end

  def normalize_calendar_month(month)
    Event.normalize_event_date(month)&.beginning_of_month&.iso8601
  end

  def current_calendar_month_param
    params[:month] if respond_to?(:params) && params.respond_to?(:[])
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
    when nil
      "null"
    when String
      value.blank? ? SavedView.property_filter_value_label(value) : value.squish
    when Hash, Array
      value.to_json
    else
      value.to_s.squish
    end
  end

  def event_filter_properties(event)
    return {} if event.properties.blank?

    event.properties.each_with_object({}) do |(key, value), result|
      filter_value = property_numeric_filter_value(value)
      result[key] = filter_value unless filter_value.nil?
    end
  end

  def event_search_text(event)
    event.search_text.presence || Event.search_text_for(event)
  end

  def event_type_count_dom_id(event_type, variant:)
    Event.event_type_count_dom_id(event_type, variant: variant)
  end

  def event_type_label(event_type)
    Event.event_type_label(event_type)
  end

  def event_type_color_class(event_type)
    "event-type-color" if event_type.present?
  end

  def event_type_color_style(event_type)
    return if event_type.blank?

    light_color, dark_color = EVENT_TYPE_COLOR_PALETTE[event_type_color_index(event_type)]

    [
      "--event-type-color-light: #{light_color}",
      "--event-type-color-dark: #{dark_color}"
    ].join("; ")
  end

  def event_type_color_index(event_type)
    normalized_event_type = Event
      .normalize_utf8_string(event_type)
      .unicode_normalize(:nfc)
      .downcase

    hash = normalized_event_type.each_codepoint.reduce(2_166_136_261) do |memo, codepoint|
      ((memo ^ codepoint) * 16_777_619) & 0xffffffff
    end

    hash % EVENT_TYPE_COLOR_PALETTE.length
  end
end
