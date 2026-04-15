require "test_helper"

class Settings::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner  = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin  = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
  end

  test "owner can see members index" do
    sign_in_as(@owner)
    get settings_members_path
    assert_response :success
    assert_select "h1", "settings"
  end

  test "admin can see members index" do
    sign_in_as(@admin)
    get settings_members_path
    assert_response :success
  end

  test "regular member CANNOT see members index" do
    sign_in_as(@member)
    get settings_members_path
    assert_response :forbidden
  end

  test "owner can see a member detail page" do
    sign_in_as(@owner)
    get settings_member_path(@member)
    assert_response :success
  end

  test "admin can see a member detail page" do
    sign_in_as(@admin)
    get settings_member_path(@member)
    assert_response :success
  end

  test "regular member CANNOT see any member detail page" do
    sign_in_as(@member)
    get settings_member_path(@member)
    assert_response :forbidden
  end

  test "returns not found for user in another account" do
    other_account = Account.create!(join_code: "OTHER123")
    outsider = other_account.users.create!(
      nickname: "Outsider",
      email_address: "outsider@example.com",
      password: "password123"
    )

    sign_in_as(@owner)
    get settings_member_path(outsider)
    assert_response :not_found
  end
end
