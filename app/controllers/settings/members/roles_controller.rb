class Settings::Members::RolesController < ApplicationController
  layout "settings"

  before_action :ensure_can_administer
  before_action :set_user, only: %i[edit update]
  before_action :ensure_can_change_role

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

  def ensure_can_change_role
    if @user.owner? && Current.user.admin?
      redirect_to settings_member_path(@user), alert: "only the account owner can change owner roles."
      return
    end

    if params.dig(:user, :role) == "owner" && Current.user.admin?
      redirect_to edit_settings_member_role_path(@user), alert: "only the account owner can promote someone to owner."
      nil
    end
  end
end
