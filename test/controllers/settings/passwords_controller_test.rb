require "test_helper"

class Settings::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "edit" do
    get edit_settings_password_path
    assert_response :success
  end

  test "update with valid parameters" do
    new_password = "newstrongpassword123"

    patch settings_password_path, params: {
      user: {
        password_challenge: "password",
        password: new_password,
        password_confirmation: new_password
      }
    }

    assert_redirected_to edit_settings_password_path
    assert_equal "done.", flash[:notice]
    assert @user.reload.authenticate(new_password)
  end

  test "update with wrong current password" do
    patch settings_password_path, params: {
      user: {
        password_challenge: "wrongpassword",
        password: "newstrongpassword123",
        password_confirmation: "newstrongpassword123"
      }
    }

    assert_redirected_to edit_settings_password_path
    assert flash[:alert].present?
  end

  test "update when new passwords do not match" do
    patch settings_password_path, params: {
      user: {
        password_challenge: "password",
        password: "newstrongpassword123",
        password_confirmation: "differentpassword"
      }
    }

    assert_redirected_to edit_settings_password_path
    assert flash[:alert].present?
  end
end
