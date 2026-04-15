class Settings::MembersController < ApplicationController
  layout "settings"

  before_action :ensure_can_administer

  def index
    @users = Current.account.users.ordered_by_role
  end

  def show
    @user = Current.account.users.find(params[:id])
  end
end
