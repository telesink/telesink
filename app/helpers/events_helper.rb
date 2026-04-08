module EventsHelper
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
end
