require "test_helper"

class Settings::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "show" do
    get settings_invitations_path
    assert_response :success
  end

  test "show displays the correct join URL for the current account" do
    get settings_invitations_path

    assert_match join_url(@user.account.join_code), response.body
  end
end
