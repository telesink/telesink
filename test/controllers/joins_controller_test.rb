require "test_helper"

class JoinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(join_code: "TESTJOIN123")
  end

  test "new with valid join code" do
    get join_path(@account.join_code)
    assert_response :success
  end

  test "new with invalid join code" do
    get join_path("INVALID")
    assert_response :not_found
  end

  test "create with valid parameters" do
    assert_difference "User.count" do
      post join_path(@account.join_code), params: {
        user: {
          nickname: "Test User",
          email_address: "newuser@example.com",
          password: "password123"
        }
      }
    end

    user = User.last
    assert_equal @account, user.account
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid parameters" do
    assert_no_difference "User.count" do
      post join_path(@account.join_code), params: {
        user: {
          email_address: "invalid-email",
          password: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create redirects to login when email already exists" do
    User.create!(
      account: @account,
      nickname: "Existing User",
      email_address: "duplicate@example.com",
      password: "password123"
    )

    post join_path(@account.join_code), params: {
      user: {
        nickname: "Duplicate",
        email_address: "duplicate@example.com",
        password: "password123"
      }
    }

    assert_redirected_to new_session_path(email_address: "duplicate@example.com")
  end

  test "create with invalid join code" do
    post join_path("INVALID"), params: {
      user: {
        nickname: "Test",
        email_address: "test@example.com",
        password: "password123"
      }
    }

    assert_response :not_found
  end

  test "new when already signed in redirects to root" do
    sign_in_as(User.take)

    get join_path(@account.join_code)
    assert_redirected_to root_path
  end

  test "create when already signed in redirects to root" do
    sign_in_as(User.take)

    assert_no_difference "User.count" do
      post join_path(@account.join_code), params: {
        user: {
          nickname: "Test User",
          email_address: "already-signed-in@example.com",
          password: "password123"
        }
      }
    end

    assert_redirected_to root_path
  end
end
