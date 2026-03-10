module EventProcessing
  extend self

  def process_event(sink, event)
    Event.transaction do
      Event.create!(
        sink: sink,
        event_type: event.event_type,
        emoji: event.emoji,
        text: event.text,
        payload: event.payload,
        occurred_at: event.occurred_at
      )
    end
  end
end
