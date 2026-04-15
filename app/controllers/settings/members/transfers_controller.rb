class Settings::Members::TransfersController < ApplicationController
  layout "settings"

  before_action :ensure_can_administer
  before_action :set_user, only: :show

  def show
    @transfer_url = session_transfer_url(@user.transfer_id)
  end

  private

  def set_user
    @user = Current.account.users.find(params[:member_id])
  end
end
