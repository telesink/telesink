require "test_helper"

class Settings::Members::TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:kyrylo))
  end

  test "show renders the account recovery page for a member in the same account" do
    get settings_member_transfer_path(users(:test_member))

    assert_response :success
    assert_match "account recovery", response.body
    assert_match "sign-in link", response.body
    assert_match %r{/session/transfer/}, response.body
  end

  test "show works when viewing yourself" do
    get settings_member_transfer_path(users(:kyrylo))
    assert_response :success
  end

  test "show returns not found for a user in another account" do
    other_account = Account.create!(join_code: "OTHER123")
    outsider = other_account.users.create!(
      nickname: "Outsider",
      email_address: "outsider@example.com",
      password: "password123"
    )

    get settings_member_transfer_path(outsider)
    assert_response :not_found
  end
end
