require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "new redirects if already authenticated" do
    sign_in_as(@user)
    get new_registration_path
    assert_redirected_to root_path
  end

  test "create with valid parameters" do
    email = "new@example.com"

    post registration_path, params: {
      user: {
        email_address: email,
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid parameters" do
    post registration_path, params: {
      user: {
        email_address: @user.email_address,
        password: "password",
        password_confirmation: "password"
      }
    }

    assert_redirected_to new_registration_path
    assert_nil cookies[:session_id]
    assert_equal "registration failed. please try a different email address.", flash[:alert]
  end

  test "create redirects if already authenticated" do
    sign_in_as(@user)
    post registration_path, params: {
      user: {
        email_address: "another@example.com",
        password: "password",
        password_confirmation: "password"
      }
    }
    assert_redirected_to root_path
  end
end
