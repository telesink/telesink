require "test_helper"

class Settings::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "index" do
    get settings_members_path
    assert_response :success
  end

  test "show" do
    get settings_member_path(@user)
    assert_response :success
  end

  test "show another member in the same account" do
    other_user = @user.account.users.create!(
      nickname: "Other Member",
      email_address: "other.member@example.com",
      password: "password123"
    )

    get settings_member_path(other_user)
    assert_response :success
  end

  test "show returns not found for user belonging to another account" do
    other_account = Account.create!(join_code: "OTHER123")
    outsider = other_account.users.create!(
      nickname: "Outsider",
      email_address: "outsider@example.com",
      password: "password123"
    )

    get settings_member_path(outsider)
    assert_response :not_found
  end
end
