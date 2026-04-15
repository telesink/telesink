class Settings::InvitationsController < ApplicationController
  layout "settings"

  before_action :ensure_can_administer

  def show
    @join_url = join_url(Current.account.join_code)
  end
end
