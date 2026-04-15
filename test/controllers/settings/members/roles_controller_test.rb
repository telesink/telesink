require "test_helper"

class Settings::Members::RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
  end

  test "owner can view edit form" do
    sign_in_as(@owner)
    get edit_settings_member_role_path(@member)
    assert_response :success
  end

  test "admin can view edit form" do
    sign_in_as(@admin)
    get edit_settings_member_role_path(@member)
    assert_response :success
  end

  test "regular member cannot view edit form" do
    sign_in_as(@member)
    get edit_settings_member_role_path(@member)
    assert_response :forbidden
  end

  test "owner can promote member to admin" do
    sign_in_as(@owner)
    patch settings_member_role_path(@member), params: { user: { role: "admin" } }

    assert_redirected_to edit_settings_member_role_path(@member)
    assert_equal "admin", @member.reload.role
  end

  test "admin can promote member to admin" do
    sign_in_as(@admin)
    patch settings_member_role_path(@member), params: { user: { role: "admin" } }

    assert_redirected_to edit_settings_member_role_path(@member)
    assert_equal "admin", @member.reload.role
  end

  test "admin CANNOT promote anyone to owner" do
    sign_in_as(@admin)
    patch settings_member_role_path(@member), params: { user: { role: "owner" } }

    assert_redirected_to edit_settings_member_role_path(@member)
    assert_equal "member", @member.reload.role # unchanged
  end

  test "owner CAN promote someone to owner" do
    sign_in_as(@owner)
    patch settings_member_role_path(@member), params: { user: { role: "owner" } }

    assert_redirected_to edit_settings_member_role_path(@member)
    assert_equal "owner", @member.reload.role
  end

  test "admin CANNOT change an owner's role" do
    sign_in_as(@admin)
    patch settings_member_role_path(@owner), params: { user: { role: "admin" } }

    assert_redirected_to settings_member_path(@owner)
    assert_equal "owner", @owner.reload.role # unchanged
  end

  test "update with invalid role" do
    sign_in_as(@owner)
    original_role = @member.role

    patch settings_member_role_path(@member), params: { user: { role: "invalid" } }

    assert_redirected_to edit_settings_member_role_path(@member)
    assert_equal original_role, @member.reload.role
  end

  test "update prevents demoting yourself from owner" do
    sign_in_as(@owner)

    patch settings_member_role_path(@owner), params: { user: { role: "member" } }

    assert_redirected_to settings_member_path(@owner)
    assert_equal "owner", @owner.reload.role
  end
end
