class Sinks::EventsController < ApplicationController
  skip_demo_restrictions only: %i[index]

  before_action :set_sink
  before_action :set_event_type

  def index
    @events = Event.feed_batch(
      @sink,
      before_id: params[:before_id],
      event_type: @event_type
    )

    render formats: [ :turbo_stream ]
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end

  def set_event_type
    @event_type = params[:event_type].to_s.strip.presence
  end
end
