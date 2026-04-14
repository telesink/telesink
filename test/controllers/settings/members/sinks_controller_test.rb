require "test_helper"

class Settings::Members::SinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:kyrylo))
  end

  test "index" do
    get settings_member_sinks_path(users(:test_member))
    assert_response :success
  end

  test "update with valid parameters" do
    member = users(:test_member)
    sink1 = member.account.sinks.create!(name: "Sink One")
    sink2 = member.account.sinks.create!(name: "Sink Two")

    patch settings_member_sinks_path(member), params: { sink_ids: [ sink1.id, sink2.id ] }

    assert_redirected_to settings_member_sinks_url(member)
    assert_equal "sink access updated.", flash[:notice]
    assert_equal [ sink1.id, sink2.id ].sort, member.reload.sink_ids.sort
  end

  test "update removes all access when no sinks are selected" do
    member = users(:test_member)
    sink = member.account.sinks.create!(name: "Test Sink")
    member.sink_memberships.create!(sink: sink)

    patch settings_member_sinks_path(member)

    assert_redirected_to settings_member_sinks_url(member)
    assert_equal "sink access updated.", flash[:notice]
    assert_empty member.reload.sink_memberships
  end

  test "update adds and removes sinks in one request" do
    member = users(:test_member)
    keep_sink = member.account.sinks.create!(name: "Keep Sink")
    remove_sink = member.account.sinks.create!(name: "Remove Sink")
    add_sink = member.account.sinks.create!(name: "Add Sink")

    member.sink_memberships.create!(sink: keep_sink)
    member.sink_memberships.create!(sink: remove_sink)

    patch settings_member_sinks_path(member), params: { sink_ids: [ keep_sink.id, add_sink.id ] }

    assert_redirected_to settings_member_sinks_url(member)
    assert_equal "sink access updated.", flash[:notice]

    accessible_ids = member.reload.sink_ids
    assert_includes accessible_ids, keep_sink.id
    assert_includes accessible_ids, add_sink.id
    assert_not_includes accessible_ids, remove_sink.id
  end
end
