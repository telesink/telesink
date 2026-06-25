class EventsController < ApplicationController
  skip_demo_restrictions only: %i[show]

  def show
    sink_ids = Current.user.sink_ids
    @event = Event.where(sink_id: sink_ids).find(params[:id])
    @sink = @event.sink
    @sink_memberships = Current
      .user
      .sink_memberships
      .joins(:sink)
      .includes(:sink)
      .order("sinks.name ASC")
  end
end
