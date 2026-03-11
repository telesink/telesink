class EventsController < ApplicationController
  def show
    @event = Event.where(sink_id: Current.user.sink_ids).find(params[:id])
    @column_id = params[:column_id]
    @sinks = Current.user.sinks.order(created_at: :asc)
  end
end
