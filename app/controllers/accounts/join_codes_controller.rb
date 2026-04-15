class Accounts::JoinCodesController < ApplicationController
  before_action :ensure_can_administer

  def create
    Current.account.reset_join_code
    redirect_to settings_invitations_url, notice: "new invite link generated."
  end
end
