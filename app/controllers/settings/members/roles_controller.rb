class Settings::Members::RolesController < ApplicationController
  layout "settings"

  before_action :set_user, only: %i[edit update]

  def edit
  end

  def update
    if @user == Current.user && Current.user.owner? && params[:user][:role] != "owner"
      redirect_to settings_member_path(@user), alert: "you cannot demote yourself from owner."
      return
    end

    role = params.dig(:user, :role)
    unless User.roles.key?(role)
      redirect_to edit_settings_member_role_path(@user), alert: "invalid role."
      return
    end

    if @user.update(role: role)
      redirect_to edit_settings_member_role_path(@user), notice: "role updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.account.users.find(params[:member_id])
  end
end
