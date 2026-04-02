module EventsHelper
  def highlighted_event_body(event, column, length: 87)
    text = if column&.search_term.present?
      highlight(event.text, column.search_term, highlighter: '<mark class="event-preview__highlight">\1</mark>')
    else
      event.text
    end

    truncate(text, length: length, omission: "…").html_safe
  end
end
