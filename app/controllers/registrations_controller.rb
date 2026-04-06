class RegistrationsController < ApplicationController
  layout "public"

  allow_unauthenticated_access

  before_action :redirect_if_authenticated, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.role = :owner

    ActiveRecord::Base.transaction do
      account = Account.create!
      @user.account = account
      @user.save!
    end

    Telesink.track(
      event: "New account",
      text: "Owner: #{@user.email_address}",
      emoji: "👤",
      properties: {
        owner: @user.id,
        user_id: @user.id,
        email_address: @user.email_address
      }
    )

    start_new_session_for @user
    redirect_to root_url
  rescue ActiveRecord::RecordInvalid
    redirect_to new_registration_url, alert: "registration failed. please try again."
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
