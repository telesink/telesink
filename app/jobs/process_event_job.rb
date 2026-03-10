class ProcessEventJob < ApplicationJob
  queue_as :events

  def perform(sink, payload)
    EventProcessing.process_event(sink, Telesink::Event.new(payload))
  end
end
