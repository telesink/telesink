require "test_helper"

class Accounts::JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
  end

  test "owner can regenerate the join code" do
    sign_in_as(@owner)

    assert_changes -> { @owner.account.reload.join_code } do
      post account_join_code_path
    end

    assert_redirected_to settings_invitations_path
    follow_redirect!

    assert_select "div", "new invite link generated."
  end

  test "admin can regenerate the join code" do
    sign_in_as(@admin)

    assert_changes -> { @admin.account.reload.join_code } do
      post account_join_code_path
    end

    assert_redirected_to settings_invitations_path
    follow_redirect!

    assert_select "div", "new invite link generated."
  end

  test "regular member CANNOT regenerate the join code" do
    sign_in_as(@member)

    original_code = @member.account.join_code

    assert_no_changes -> { @member.account.reload.join_code } do
      post account_join_code_path
    end

    assert_response :forbidden
  end

  test "create resets the account join code and redirects with notice (owner)" do
    sign_in_as(@owner)

    assert_changes -> { @owner.account.reload.join_code } do
      post account_join_code_path
    end

    assert_redirected_to settings_invitations_path

    follow_redirect!

    assert_select "div", "new invite link generated."
  end
end
