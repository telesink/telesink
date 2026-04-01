require "test_helper"

class Sinks::Columns::ViewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:kyrylo))
  end

  test "updates column_last_viewed_at for the current user when they are a member" do
    sink = users(:kyrylo).sinks.create!(name: "View Tracking Test Sink")
    column = sink.columns.create!(name: "Test Column")

    membership = sink.sink_memberships.find_or_create_by!(user: users(:kyrylo))

    assert_nil membership.column_last_viewed_at[column.id.to_s]

    post sink_column_views_path(sink, column)

    assert_response :ok

    membership.reload
    timestamp = membership.column_last_viewed_at[column.id.to_s]
    assert timestamp.present?
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, timestamp)
  end

  test "gracefully returns :ok (no-op) when the user has no membership in the sink" do
    sink = users(:kyrylo).sinks.create!(name: "No Membership Test Sink")
    column = sink.columns.create!(name: "Test Column")

    sink.sink_memberships.where(user: users(:kyrylo)).destroy_all

    post sink_column_views_path(sink, column)

    assert_response :ok
    assert_not sink.sink_memberships.exists?(user: users(:kyrylo))
  end

  test "requires authentication" do
    sign_out

    sink = users(:kyrylo).sinks.create!(name: "Auth Test Sink")
    column = sink.columns.create!(name: "Test Column")

    post sink_column_views_path(sink, column)

    assert_response :redirect
    assert_redirected_to new_session_path
  end
end
