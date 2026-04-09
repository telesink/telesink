require "test_helper"

class SinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "index redirects to user's last visited sink when available" do
    sink = @user.sinks.create!(name: "Last Visited Sink")
    @user.update!(current_sink_id: sink.id)

    get sinks_path
    assert_redirected_to sink
  end

  test "index falls back to first sink (alphabetical by name) when no current_sink_id is set" do
    @user.update!(current_sink_id: nil)

    get sinks_path
    assert_redirected_to @user.sinks.order(name: :asc).first
  end

  test "index falls back to first sink when current_sink_id points to a deleted sink" do
    old_sink = @user.sinks.create!(name: "Old Sink")
    @user.update!(current_sink_id: old_sink.id)
    old_sink.destroy!

    get sinks_path
    assert_redirected_to @user.sinks.order(name: :asc).first
  end

  test "index renders when user has no sinks" do
    Sink.destroy_all
    get sinks_path
    assert_response :success
  end

  test "show" do
    sink = @user.sinks.create!(name: "Test Sink")
    get sink_path(sink)
    assert_response :success
  end

  test "show marks the sink as read for the current user (clears has_unread_events)" do
    sink = @user.sinks.create!(name: "Unread Test Sink")

    membership = @user.sink_memberships.find_by(sink: sink)
    membership.update!(has_unread_events: true)

    get sink_path(sink)

    assert_response :success
    assert_not membership.reload.has_unread_events?
  end

  test "show gracefully handles a sink that is already marked as read" do
    sink = @user.sinks.create!(name: "Already Read Sink")

    get sink_path(sink)

    assert_response :success

    membership = @user.sink_memberships.find_by(sink: sink)
    assert_not membership.has_unread_events?
  end

  test "new" do
    get new_sink_path
    assert_response :success
  end

  test "create with valid parameters" do
    assert_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "My Awesome Sink" } }
    end

    sink = Sink.last
    assert_redirected_to sink
    assert_includes sink.users, @user
  end

  test "create with invalid parameters" do
    assert_no_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "edit" do
    sink = @user.sinks.create!(name: "Edit Sink")
    get edit_sink_path(sink)
    assert_response :success
  end

  test "update with valid parameters" do
    sink = @user.sinks.create!(name: "Old Name")

    patch sink_path(sink), params: { sink: { name: "New Name" } }

    assert_redirected_to sink
    assert_equal "New Name", sink.reload.name
  end

  test "update with invalid parameters" do
    sink = @user.sinks.create!(name: "Old Name")

    patch sink_path(sink), params: { sink: { name: "" } }

    assert_response :unprocessable_entity
  end

  test "destroy redirects to next remaining sink" do
    sink = @user.sinks.create!(name: "new sink")

    assert_difference "Sink.count", -1 do
      delete sink_path(sink)
    end

    assert_redirected_to @user.sinks.order(name: :asc).first
  end

  test "destroy last sink redirects to index" do
    @user.sinks.destroy_all
    last_sink = @user.sinks.create!(name: "Last Remaining Sink")

    delete sink_path(last_sink)

    assert_redirected_to sinks_path
  end
end
