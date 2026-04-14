class Sessions::TransfersController < ApplicationController
  allow_unauthenticated_access

  def show
    if user = User.find_by_transfer_id(params[:id])
      start_new_session_for user
      redirect_to Current.sink || sinks_path
    else
      redirect_to new_session_path, alert: "this sign-in link is invalid or has expired."
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "this sign-in link is invalid or has expired."
  end
end
