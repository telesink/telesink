class Sinks::Columns::EventsController < ApplicationController
  include SinkScoped, ColumnScoped

  skip_demo_restrictions only: %i[index]

  before_action :set_cutoff, only: %i[index]

  def index
    @events = @column.recent_events(
      limit: 30,
      before_id: params[:before_id].to_i
    )
    render formats: [ :turbo_stream ]
  end

  private

  def set_cutoff
    membership = @sink.sink_memberships.find_by(user: Current.user)
    @cutoff = membership&.last_viewed_at_for(@column)
  end
end
