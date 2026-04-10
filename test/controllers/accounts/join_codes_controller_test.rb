require "test_helper"

class Accounts::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "create resets the account join code and redirects with notice" do
    assert_changes -> { @user.account.reload.join_code } do
      post account_join_code_path
    end

    assert_redirected_to settings_invitations_path

    follow_redirect!

    assert_select "div", "new invite link generated."
  end
end
