class EventsController < ApplicationController
  def show
    sink_ids = Current.user.sink_ids
    @event = Event.where(sink_id: sink_ids).find(params[:id])
    @column = Column.where(sink_id: sink_ids).find(params[:column_id])
    @sink_memberships = Current.user.sink_memberships.order(:created_at)
  end
end
