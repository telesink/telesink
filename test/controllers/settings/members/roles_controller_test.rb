require "test_helper"

class Settings::Members::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:kyrylo))
  end

  test "edit" do
    get edit_settings_member_role_path(users(:test_member))
    assert_response :success
  end

  test "update with valid parameters" do
    patch settings_member_role_path(users(:test_member)), params: { user: { role: "admin" } }

    assert_redirected_to edit_settings_member_role_path(users(:test_member))
    assert_equal "admin", users(:test_member).reload.role
  end

  test "update with invalid role" do
    original_role = users(:test_member).role

    patch settings_member_role_path(users(:test_member)), params: { user: { role: "invalid" } }

    assert_response :unprocessable_entity
    assert_equal original_role, users(:test_member).reload.role
  end

  test "update prevents demoting yourself from owner" do
    users(:kyrylo).update!(role: "owner")

    patch settings_member_role_path(users(:kyrylo)), params: { user: { role: "member" } }

    assert_redirected_to settings_member_path(users(:kyrylo))
    assert_equal "owner", users(:kyrylo).reload.role
  end
end
