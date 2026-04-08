class SettingsController < ApplicationController
  layout "settings"

  def show
    redirect_to edit_settings_nickname_path
  end
end
