require "test_helper"

class Settings::Members::TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
  end

  test "owner can view transfer page for a member" do
    sign_in_as(@owner)
    get settings_member_transfer_path(@member)

    assert_response :success
    assert_match "account recovery", response.body
    assert_match "sign-in link", response.body
    assert_match %r{/session/transfer/}, response.body
  end

  test "admin can view transfer page for a member" do
    sign_in_as(@admin)
    get settings_member_transfer_path(@member)
    assert_response :success
  end

  test "regular member cannot view transfer page" do
    sign_in_as(@member)
    get settings_member_transfer_path(@member)
    assert_response :forbidden
  end

  test "works when viewing yourself" do
    sign_in_as(@owner)
    get settings_member_transfer_path(@owner)
    assert_response :success
  end

  test "returns not found for a user in another account" do
    other_account = Account.create!(join_code: "OTHER123")
    outsider = other_account.users.create!(
      nickname: "Outsider",
      email_address: "outsider@example.com",
      password: "password123"
    )

    sign_in_as(@owner)
    get settings_member_transfer_path(outsider)
    assert_response :not_found
  end

  test "displays the correct transfer URL" do
    sign_in_as(@owner)
    get settings_member_transfer_path(@member)

    assert_match %r{/session/transfer/[A-Za-z0-9\-_=]+}, response.body
    assert_match /value="http[^"]*\/session\/transfer\/[A-Za-z0-9\-_=]+"/, response.body
  end
end
