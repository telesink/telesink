class Settings::PasswordsController < ApplicationController
  layout "settings"

  def edit
  end

  def update
    if Current.user.update(password_params)
      Current.user.sessions.where.not(id: Current.session&.id).destroy_all

      redirect_to edit_settings_password_path, notice: "done."
    else
      redirect_to edit_settings_password_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation, :password_challenge)
  end
end
