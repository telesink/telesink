class Settings::Members::SinksController < ApplicationController
  layout "settings"

  before_action :ensure_can_administer
  before_action :set_user, only: %i[index update]

  def index
    @sinks = Current.account.sinks.order(:name)
    @accessible_sink_ids = @user.sink_memberships.pluck(:sink_id).to_set
  end

  def update
    desired_ids = (params[:sink_ids] || []).map(&:to_i)
    current_ids = @user.sink_memberships.pluck(:sink_id)

    @user.sink_memberships.where(sink_id: current_ids - desired_ids).destroy_all
    (desired_ids - current_ids).each do |id|
      @user.sink_memberships.create_or_find_by!(sink_id: id)
    end

    redirect_to settings_member_sinks_url(@user), notice: "sink access updated."
  end

  private

  def set_user
    @user = Current.account.users.find(params[:member_id])
  end
end
