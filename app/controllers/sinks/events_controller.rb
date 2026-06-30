class Sinks::EventsController < ApplicationController
  skip_demo_restrictions only: %i[index]

  before_action :set_sink
  before_action :set_feed_filters

  def index
    @events = Event.feed_batch(
      @sink,
      before_id: params[:before_id],
      event_type: @event_type,
      date: @event_date,
      property_key: @property_key,
      property_op: @property_op,
      property_value: @property_value,
      search_query: @search_query,
      time_zone: browser_time_zone
    )

    render formats: [ :turbo_stream ]
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end

  def set_feed_filters
    filters = Event.normalize_feed_filters(params)

    @event_type = filters[:event_type]
    @event_date = filters[:event_date]
    @search_query = filters[:search_query]
    @property_key = filters[:property_key]
    @property_op = filters[:property_op]
    @property_value = filters[:property_value]
  end
end
