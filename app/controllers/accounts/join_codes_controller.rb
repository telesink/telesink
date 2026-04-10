class Accounts::JoinCodesController < ApplicationController
  def create
    Current.account.reset_join_code
    redirect_to settings_invitations_url, notice: "new invite link generated."
  end
end
