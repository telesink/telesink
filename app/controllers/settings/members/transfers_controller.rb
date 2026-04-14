class Settings::Members::TransfersController < ApplicationController
  layout "settings"

  def show
    @user = Current.account.users.find(params[:member_id])
    @transfer_url = session_transfer_url(@user.transfer_id)
  end
end
