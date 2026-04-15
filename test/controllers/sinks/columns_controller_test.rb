require "test_helper"

class Sinks::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner  = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin  = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
    @sink = @owner.sinks.create!(name: "Test Sink", account: accounts(:telebugs))
  end

  test "any user can show a column (turbo stream)" do
    sign_in_as(@member)
    column = @sink.columns.create!(name: "All Events")

    get sink_column_path(@sink, column)

    assert_response :success
  end

  test "owner can create a column" do
    sign_in_as(@owner)
    assert_difference "@sink.columns.count" do
      post sink_columns_path(@sink), as: :turbo_stream
    end
    assert_response :success
  end

  test "admin can create a column" do
    sign_in_as(@admin)
    assert_difference "@sink.columns.count" do
      post sink_columns_path(@sink), as: :turbo_stream
    end
    assert_response :success
  end

  test "regular member CANNOT create a column" do
    sign_in_as(@member)
    assert_no_difference "@sink.columns.count" do
      post sink_columns_path(@sink)
    end
    assert_response :forbidden
  end

  test "owner can edit a column" do
    sign_in_as(@owner)
    column = @sink.columns.create!(name: "Old Name")

    get edit_sink_column_path(@sink, column)
    assert_response :success
  end

  test "member CANNOT edit a column" do
    sign_in_as(@member)
    column = @sink.columns.create!(name: "Old Name")

    get edit_sink_column_path(@sink, column)
    assert_response :forbidden
  end

  test "owner can update a column" do
    sign_in_as(@owner)
    column = @sink.columns.create!(name: "Old Name")

    patch sink_column_path(@sink, column), params: { column: { name: "New Name" } }

    assert_redirected_to @sink
    assert_equal "New Name", column.reload.name
  end

  test "member CANNOT update a column" do
    sign_in_as(@member)
    column = @sink.columns.create!(name: "Old Name")

    patch sink_column_path(@sink, column), params: { column: { name: "New Name" } }
    assert_response :forbidden
  end

  test "owner can destroy a column" do
    sign_in_as(@owner)
    column = @sink.columns.create!(name: "To Delete")

    assert_difference "@sink.columns.count", -1 do
      delete sink_column_path(@sink, column)
    end
    assert_redirected_to @sink
  end

  test "member CANNOT destroy a column" do
    sign_in_as(@member)
    column = @sink.columns.create!(name: "To Delete")

    assert_no_difference "@sink.columns.count" do
      delete sink_column_path(@sink, column)
    end
    assert_response :forbidden
  end
end
