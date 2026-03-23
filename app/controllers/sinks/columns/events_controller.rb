class Sinks::Columns::EventsController < ApplicationController
  include SinkScoped, ColumnScoped

  def index
    @events = @column.recent_events(
      limit: 30,
      before_id: params[:before_id].to_i
    )
    render formats: [ :turbo_stream ]
  end
end
