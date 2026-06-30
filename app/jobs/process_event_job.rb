class ProcessEventJob < ApplicationJob
  queue_as :events

  def perform(sink, payload)
    event = Telesink::Event.new(payload)

    if event.idempotency_key && Event.exists?(sink_id: sink.id, idempotency_key: event.idempotency_key)
      return
    end

    EventProcessing.process_event(sink, event)
  rescue ActiveRecord::RecordNotUnique
    raise unless event&.idempotency_key
  end
end
