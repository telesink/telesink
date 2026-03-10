module EventProcessing
  extend self

  def process_event(sink, telesink_event)
    Event.transaction do
      Event.create!(
        sink: sink,
        event_type: telesink_event.event_type,
        emoji: telesink_event.emoji,
        text: telesink_event.text,
        payload: telesink_event.payload,
        occurred_at: telesink_event.occurred_at
      )
    end
  end
end
