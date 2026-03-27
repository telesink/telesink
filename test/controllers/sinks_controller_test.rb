require "test_helper"

class SinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as(@user)
  end

  test "index redirects to first sink when sinks exist" do
    get sinks_path
    assert_redirected_to Sink.first
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

    assert_redirected_to Sink.first
  end

  test "destroy last sink redirects to index" do
    delete sink_path(Sink.first)

    assert_redirected_to sinks_path
  end
end
