require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:kyrylo)
    sign_in_as @user
  end

  test "show renders successfully" do
    sink = @user.sinks.first || @user.sinks.create!(name: "Test Sink")
    event = sink.events.create!(
      event_type: "test_event",
      occurred_at: Time.current
    )

    get event_path(event), params: { column_id: columns(:all_telebugs).id }

    assert_response :success
  end

  test "show returns not found for event from inaccessible sink" do
    foreign_sink = Sink.create!(name: "Foreign Sink")
    event = foreign_sink.events.create!(
      event_type: "test_event",
      occurred_at: Time.current
    )

    get event_path(event)
    assert_response :not_found
  end

  test "show works even when user has no sinks" do
    @user.sinks.destroy_all

    sink = @user.sinks.create!(name: "Test Sink")
    column = sink.columns.create!(name: "all events")
    event = sink.events.create!(
      event_type: "test_event",
      occurred_at: Time.current
    )

    get event_path(event), params: { column_id: column.id }
    assert_response :success
  end
end
