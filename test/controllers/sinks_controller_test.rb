require "test_helper"

class SinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner  = users(:kyrylo)
    @admin  = users(:test_admin)
    @member = users(:test_member)
    @account = accounts(:telebugs)
  end

  test "any user can access index (redirects to last visited sink)" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Last Visited Sink", account: @account)
    @member.update!(current_sink_id: sink.id)

    get sinks_path
    assert_redirected_to sink
  end

  test "index falls back to first sink (alphabetical) when no current_sink_id" do
    sign_in_as(@owner)
    @owner.update!(current_sink_id: nil)

    get sinks_path
    assert_redirected_to @owner.sinks.order(name: :asc).first
  end

  test "index falls back to first sink when current_sink_id points to a deleted sink" do
    sign_in_as(@owner)
    old_sink = @owner.sinks.create!(name: "Old Sink", account: @account)
    @owner.update!(current_sink_id: old_sink.id)
    old_sink.destroy!

    get sinks_path
    assert_redirected_to @owner.sinks.order(name: :asc).first
  end

  test "index renders empty state when user has no sinks" do
    Sink.destroy_all
    sign_in_as(@member)

    get sinks_path
    assert_response :success
  end

  test "any user can view a sink they belong to" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Test Sink", account: @account)

    get sink_path(sink)
    assert_response :success
  end

  test "demo environment renders account footer without profile or logout links" do
    sign_in_as(@owner)

    with_rails_env("demo") do
      get sink_path(sinks(:telebugs))
    end

    assert_response :success
    assert_select ".sidebar-account", /~#{@owner.nickname}/
    assert_select ".sidebar-account a", count: 0
    assert_select ".sidebar-account form", count: 0
    assert_no_match "log out", response.body
  end

  test "show marks the sink as read for the current user" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Unread Test Sink", account: @account)

    membership = @member.sink_memberships.find_by(sink: sink)
    membership.update!(has_unread_events: true)

    get sink_path(sink)

    assert_response :success
    assert_not membership.reload.has_unread_events?
  end

  test "show gracefully handles a sink that is already marked as read" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Already Read Sink", account: @account)

    get sink_path(sink)

    assert_response :success
    membership = @member.sink_memberships.find_by(sink: sink)
    assert_not membership.has_unread_events?
  end

  test "owner can see new sink form" do
    sign_in_as(@owner)
    get new_sink_path
    assert_response :success
  end

  test "admin can see new sink form" do
    sign_in_as(@admin)
    get new_sink_path
    assert_response :success
  end

  test "regular member CANNOT see new sink form" do
    sign_in_as(@member)
    get new_sink_path
    assert_response :forbidden
  end

  test "owner can create a sink" do
    sign_in_as(@owner)
    assert_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "My Awesome Sink" } }
    end

    sink = Sink.last
    assert_redirected_to sink
    assert_includes sink.users, @owner
  end

  test "admin can create a sink" do
    sign_in_as(@admin)
    assert_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "Admin Sink" } }
    end
    assert_redirected_to Sink.last
  end

  test "regular member CANNOT create a sink" do
    sign_in_as(@member)
    assert_no_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "Forbidden Sink" } }
    end
    assert_response :forbidden
  end

  test "create with invalid parameters still returns unprocessable_entity (for authorized users)" do
    sign_in_as(@owner)
    assert_no_difference "Sink.count" do
      post sinks_path, params: { sink: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "owner can edit a sink" do
    sign_in_as(@owner)
    sink = @owner.sinks.create!(name: "Old Name", account: @account)

    get edit_sink_path(sink)
    assert_response :success
  end

  test "member CANNOT edit a sink" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Old Name", account: @account)

    get edit_sink_path(sink)
    assert_response :forbidden
  end

  test "owner can update a sink" do
    sign_in_as(@owner)
    sink = @owner.sinks.create!(name: "Old Name", account: @account)

    patch sink_path(sink), params: { sink: { name: "New Name" } }

    assert_redirected_to sink
    assert_equal "New Name", sink.reload.name
  end

  test "member CANNOT update a sink" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "Old Name", account: @account)

    patch sink_path(sink), params: { sink: { name: "New Name" } }
    assert_response :forbidden
  end

  test "update with invalid parameters returns unprocessable_entity (for authorized users)" do
    sign_in_as(@owner)
    sink = @owner.sinks.create!(name: "Old Name", account: @account)

    patch sink_path(sink), params: { sink: { name: "" } }

    assert_response :unprocessable_entity
  end

  test "owner can destroy a sink and is redirected to the next remaining sink" do
    sign_in_as(@owner)

    @owner.sinks.delete_all

    # Ensure there will be a "next" sink after deletion
    sink_to_delete = @owner.sinks.create!(name: "To Be Deleted", account: @account)
    remaining_sink = @owner.sinks.create!(name: "Remaining Sink", account: @account)

    assert_difference "Sink.count", -1 do
      delete sink_path(sink_to_delete)
    end

    assert_redirected_to remaining_sink
  end

  test "member CANNOT destroy a sink" do
    sign_in_as(@member)
    sink = @member.sinks.create!(name: "To Be Deleted", account: @account)

    assert_no_difference "Sink.count" do
      delete sink_path(sink)
    end
    assert_response :forbidden
  end

  test "destroy last sink redirects to index" do
    sign_in_as(@owner)
    @owner.sinks.destroy_all
    last_sink = @owner.sinks.create!(name: "Last Remaining Sink", account: @account)

    delete sink_path(last_sink)

    assert_redirected_to sinks_path
  end
end
