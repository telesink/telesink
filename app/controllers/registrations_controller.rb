class RegistrationsController < ApplicationController
  layout "public"

  allow_unauthenticated_access

  before_action :redirect_if_authenticated, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to root_url
    else
      redirect_to new_registration_url, alert: @user.errors.first.full_message
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to new_registration_url, alert: "registration failed. please try a different email address."
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end

  def redirect_if_authenticated
    redirect_to after_authentication_url if authenticated?
  end
end
