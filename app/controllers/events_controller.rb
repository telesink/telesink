class EventsController < ApplicationController
  def show
    @event = Event.find(params[:id])
    @column_id = params[:column_id]
  end
end
