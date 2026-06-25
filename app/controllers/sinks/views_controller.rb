class Sinks::ViewsController < ApplicationController
  skip_demo_restrictions only: %i[create]

  before_action :set_sink

  def create
    @sink.sink_memberships.find_by(user: Current.user)&.mark_sink_viewed!

    head :ok
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end
end
