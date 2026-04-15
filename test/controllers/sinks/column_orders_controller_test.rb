require "test_helper"

class Sinks::ColumnOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:kyrylo)
    @owner.update!(role: :owner)
    @admin = users(:test_admin)
    @admin.update!(role: :admin)
    @member = users(:test_member)
    @sink = @owner.sinks.create!(name: "Reorder Test Sink", account: accounts(:telebugs))
  end

  test "owner can reorder columns" do
    sign_in_as(@owner)

    default_column = @sink.columns.find_by!(name: "all events")
    column_a = @sink.columns.create!(name: "Column A")
    column_b = @sink.columns.create!(name: "Column B")
    column_c = @sink.columns.create!(name: "Column C")

    new_order_ids = [ column_c.id, column_a.id, default_column.id, column_b.id ]

    patch sink_column_order_path(@sink), params: {
      column_order: { column_ids: new_order_ids }
    }

    assert_response :ok
    assert_equal [ column_c, column_a, default_column, column_b ],
                 @sink.columns.order(:position).to_a
  end

  test "admin can reorder columns" do
    sign_in_as(@admin)

    default_column = @sink.columns.find_by!(name: "all events")
    column_a = @sink.columns.create!(name: "Column A")
    column_b = @sink.columns.create!(name: "Column B")

    new_order_ids = [ column_b.id, default_column.id, column_a.id ]

    patch sink_column_order_path(@sink), params: {
      column_order: { column_ids: new_order_ids }
    }

    assert_response :ok
    assert_equal [ column_b, default_column, column_a ],
                 @sink.columns.order(:position).to_a
  end

  test "regular member CANNOT reorder columns" do
    sign_in_as(@member)

    default_column = @sink.columns.find_by!(name: "all events")
    column_a = @sink.columns.create!(name: "Column A")
    column_b = @sink.columns.create!(name: "Column B")

    original_order = @sink.columns.order(:position).to_a

    patch sink_column_order_path(@sink), params: {
      column_order: { column_ids: [ column_b.id, column_a.id, default_column.id ] }
    }

    assert_response :forbidden
    assert_equal original_order, @sink.columns.order(:position).to_a
  end

  test "gracefully accepts empty column_ids array" do
    sign_in_as(@owner)

    default_column = @sink.columns.find_by!(name: "all events")

    patch sink_column_order_path(@sink), params: {
      column_order: { column_ids: [] }
    }

    assert_response :ok
    assert_equal [ default_column ], @sink.columns.order(:position).to_a
  end

  test "requires authentication" do
    sign_out

    sink = @owner.sinks.create!(name: "Auth Test Sink", account: accounts(:telebugs))
    column = sink.columns.create!(name: "Test Column")

    patch sink_column_order_path(sink), params: {
      column_order: { column_ids: [ column.id ] }
    }

    assert_redirected_to new_session_path
  end
end
