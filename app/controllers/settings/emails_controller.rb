class Settings::EmailsController < ApplicationController
  layout "settings"

  def edit
  end

  def update
    if Current.user.update(email_params)
      redirect_to edit_settings_email_path, notice: "done."
    else
      redirect_to edit_settings_email_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end

  private

  def email_params
    params.require(:user).permit(:email_address)
  end
end
