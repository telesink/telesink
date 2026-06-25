class Sinks::EventsController < ApplicationController
  skip_demo_restrictions only: %i[index]

  before_action :set_sink
  before_action :set_event_type
  before_action :set_event_date

  def index
    @events = Event.feed_batch(
      @sink,
      before_id: params[:before_id],
      event_type: @event_type,
      date: @event_date
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

  def set_event_date
    return if params[:date].blank?

    @event_date = Date.iso8601(params[:date])
  rescue Date::Error
    @event_date = nil
  end
end
