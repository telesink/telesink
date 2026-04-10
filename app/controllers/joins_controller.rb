class JoinsController < ApplicationController
  layout "public"

  require_unauthenticated_access only: %i[new create]

  before_action :verify_join_code, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params.merge(account: @account))

    if @user.save
      start_new_session_for @user
      redirect_to root_url
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to new_session_url(email_address: user_params[:email_address])
  end

  private

  def verify_join_code
    @account = Account.find_by(join_code: params[:join_code])
    head :not_found unless @account
  end

  def user_params
    params.require(:user).permit(:nickname, :email_address, :password)
  end
end
