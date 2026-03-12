class EventsController < ApplicationController
  def show
    sink_ids = Current.user.sink_ids
    @event = Event.where(sink_id: sink_ids).find(params[:id])
    @column = Column.where(sink_id: sink_ids).find(params[:column_id])
    @sinks = Current.user.sinks.order(created_at: :asc)
  end
end
