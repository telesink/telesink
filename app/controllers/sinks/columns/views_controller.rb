class Sinks::Columns::ViewsController < ApplicationController
  include SinkScoped, ColumnScoped

  before_action :set_membership, only: %i[create]
  before_action :verify_membership, only: %i[create]

  def create
    @membership.column_last_viewed_at[@column.id.to_s] = Time.current.iso8601
    @membership.save!

    head :ok
  end

  private

  def set_membership
    @membership = @sink.sink_memberships.find_by(user: Current.user)
  end

  def verify_membership
    head :ok unless @membership
  end
end
