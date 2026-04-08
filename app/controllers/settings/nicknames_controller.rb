class Settings::NicknamesController < ApplicationController
  layout "settings"

  def edit
  end

  def update
    if Current.user.update(nickname_params)
      redirect_to edit_settings_nickname_path, notice: "done."
    else
      redirect_to edit_settings_nickname_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end

  private

  def nickname_params
    params.require(:user).permit(:nickname)
  end
end
