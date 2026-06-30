class EventsController < ApplicationController
  skip_demo_restrictions only: %i[show]

  before_action :set_feed_context, only: %i[show]

  def show
    sink_ids = Current.user.sink_ids
    @event = Event.includes(sink: :folder).where(sink_id: sink_ids).find(params[:id])
    @sink = @event.sink
    @sink_memberships = Current
      .user
      .sink_memberships
      .joins(:sink)
      .includes(sink: :folder)
      .order("sinks.name ASC")
  end

  private

  def set_feed_context
    filters = Event.normalize_feed_filters(params)

    @event_type = filters[:event_type]
    @event_date = filters[:event_date]
    @search_query = filters[:search_query]
    @property_key = filters[:property_key]
    @property_op = filters[:property_op]
    @property_value = filters[:property_value]
  end
end
