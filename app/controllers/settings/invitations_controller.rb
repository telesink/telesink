class Settings::InvitationsController < ApplicationController
  layout "settings"

  def show
    @join_url = join_url(Current.account.join_code)
  end
end
