class Settings::MembersController < ApplicationController
  layout "settings"

  def index
    @users = Current.account.users.ordered_by_role
  end

  def show
    @user = Current.account.users.find(params[:id])
  end
end
