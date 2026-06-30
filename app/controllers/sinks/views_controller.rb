class Sinks::ViewsController < ApplicationController
  skip_demo_restrictions only: %i[create]

  before_action :set_sink

  def create
    if Event.feed_can_mark_viewed?(params)
      @sink.sink_memberships.find_by(user: Current.user)&.mark_sink_viewed!
    end

    head :ok
  end

  private

  def set_sink
    @sink = Current.user.sinks.find(params[:sink_id])
  end
end
