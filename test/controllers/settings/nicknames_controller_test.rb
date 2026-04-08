require "test_helper"

class Settings::NicknamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "edit" do
    get edit_settings_nickname_path
    assert_response :success
  end

  test "update with valid parameters" do
    patch settings_nickname_path, params: { user: { nickname: "newcoolnickname" } }

    assert_redirected_to edit_settings_nickname_path
    assert_equal "done.", flash[:notice]
    assert_equal "newcoolnickname", @user.reload.nickname
  end

  test "update with invalid parameters (blank nickname)" do
    original_nickname = @user.nickname

    patch settings_nickname_path, params: { user: { nickname: "" } }

    assert_redirected_to edit_settings_nickname_path
    assert flash[:alert].present?
    assert_equal original_nickname, @user.reload.nickname
  end
end
