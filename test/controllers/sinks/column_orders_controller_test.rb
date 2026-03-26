# test/controllers/sinks/column_orders_controller_test.rb
require "test_helper"

class Sinks::ColumnOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:kyrylo))
  end

  test "reorders columns when valid column_ids are supplied" do
    sink = users(:kyrylo).sinks.create!(name: "Reorder Test Sink")

    default_column = sink.columns.find_by!(name: "all events")

    column_a = sink.columns.create!(name: "Column A")
    column_b = sink.columns.create!(name: "Column B")
    column_c = sink.columns.create!(name: "Column C")

    new_order_ids = [ column_c.id, column_a.id, default_column.id, column_b.id ]

    patch sink_column_order_path(sink), params: {
      column_order: { column_ids: new_order_ids }
    }

    assert_response :ok
    assert_equal [ column_c, column_a, default_column, column_b ],
                 sink.columns.reload.to_a
  end

  test "gracefully accepts empty column_ids array" do
    sink = users(:kyrylo).sinks.create!(name: "Empty Order Test")

    default_column = sink.columns.find_by!(name: "all events")

    patch sink_column_order_path(sink), params: {
      column_order: { column_ids: [] }   # now handled correctly
    }

    assert_response :ok
    assert_equal [ default_column ], sink.columns.reload.to_a
  end

  test "requires authentication" do
    sign_out

    sink = users(:kyrylo).sinks.create!(name: "Auth Test Sink")
    column = sink.columns.create!(name: "Test Column")

    patch sink_column_order_path(sink), params: {
      column_order: { column_ids: [ column.id ] }
    }

    assert_response :redirect
    assert_redirected_to new_session_path
  end
end
