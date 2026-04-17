require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
    @account = accounts(:telebugs)
  end

  test "owner can see new folder form" do
    sign_in_as(@owner)
    get new_folder_path
    assert_response :success
  end

  test "admin can see new folder form" do
    sign_in_as(@admin)
    get new_folder_path
    assert_response :success
  end

  test "regular member CANNOT see new folder form" do
    sign_in_as(@member)
    get new_folder_path
    assert_response :forbidden
  end

  test "owner can create a folder" do
    sign_in_as(@owner)
    assert_difference "Folder.count" do
      post folders_path, params: { folder: { name: "My New Folder" } }
    end
    assert_redirected_to sinks_path
  end

  test "admin can create a folder" do
    sign_in_as(@admin)
    assert_difference "Folder.count" do
      post folders_path, params: { folder: { name: "Admin Folder" } }
    end
    assert_redirected_to sinks_path
  end

  test "regular member CANNOT create a folder" do
    sign_in_as(@member)
    assert_no_difference "Folder.count" do
      post folders_path, params: { folder: { name: "Forbidden Folder" } }
    end
    assert_response :forbidden
  end

  test "create with invalid parameters still returns unprocessable_entity (for authorized users)" do
    sign_in_as(@owner)
    assert_no_difference "Folder.count" do
      post folders_path, params: { folder: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "owner can edit a folder" do
    sign_in_as(@owner)
    folder = @account.folders.create!(name: "Old Folder Name")

    get edit_folder_path(folder)
    assert_response :success
  end

  test "member CANNOT edit a folder" do
    sign_in_as(@member)
    folder = @account.folders.create!(name: "Old Folder Name")

    get edit_folder_path(folder)
    assert_response :forbidden
  end

  # === Update ===
  test "owner can update a folder" do
    sign_in_as(@owner)
    folder = @account.folders.create!(name: "Old Name")

    patch folder_path(folder), params: { folder: { name: "New Name" } }

    assert_redirected_to sinks_path
    assert_equal "New Name", folder.reload.name
  end

  test "member CANNOT update a folder" do
    sign_in_as(@member)
    folder = @account.folders.create!(name: "Old Name")

    patch folder_path(folder), params: { folder: { name: "New Name" } }
    assert_response :forbidden
  end

  test "update with invalid parameters returns unprocessable_entity (for authorized users)" do
    sign_in_as(@owner)
    folder = @account.folders.create!(name: "Old Name")

    patch folder_path(folder), params: { folder: { name: "" } }

    assert_response :unprocessable_entity
  end

  # === Destroy ===
  test "owner can destroy a folder" do
    sign_in_as(@owner)
    folder = @account.folders.create!(name: "To Be Deleted")

    assert_difference "Folder.count", -1 do
      delete folder_path(folder)
    end

    assert_redirected_to sinks_path
  end

  test "member CANNOT destroy a folder" do
    sign_in_as(@member)
    folder = @account.folders.create!(name: "To Be Deleted")

    assert_no_difference "Folder.count" do
      delete folder_path(folder)
    end
    assert_response :forbidden
  end
end
