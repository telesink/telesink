module EventProcessing
  extend self

  def process_event(sink, event)
    Event.transaction do
      Event.create!(
        sink: sink,
        event_type: event.event_type,
        emoji: event.emoji,
        text: event.text,
        properties: event.properties,
        occurred_at: event.occurred_at || Time.current,
        idempotency_key: event.idempotency_key,
        sdk_name: event.sdk_name,
        sdk_version: event.sdk_version
      )
    end
  end
end
