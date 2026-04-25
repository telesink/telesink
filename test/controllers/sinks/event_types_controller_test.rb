require "test_helper"

class Sinks::EventTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner  = users(:kyrylo)
    @admin  = users(:test_admin)
    @member = users(:test_member)
    @sink   = sinks(:telebugs)

    @event_type = "product_viewed"

    @sink.events.where(event_type: @event_type).destroy_all
    3.times do
      @sink.events.create!(
        event_type: @event_type,
        text: "Test event",
        occurred_at: Time.current
      )
    end
  end

  test "owner can list event types" do
    sign_in_as(@owner)
    get sink_event_types_path(@sink)
    assert_response :success
  end

  test "admin can list event types" do
    sign_in_as(@admin)
    get sink_event_types_path(@sink)
    assert_response :success
  end

  test "regular member CANNOT list event types" do
    sign_in_as(@member)
    get sink_event_types_path(@sink)
    assert_response :forbidden
  end

  test "owner can view event type detail" do
    sign_in_as(@owner)
    get sink_event_type_path(@sink, @event_type)
    assert_response :success
  end

  test "admin can view event type detail" do
    sign_in_as(@admin)
    get sink_event_type_path(@sink, @event_type)
    assert_response :success
  end

  test "regular member CANNOT view event type detail" do
    sign_in_as(@member)
    get sink_event_type_path(@sink, @event_type)
    assert_response :forbidden
  end

  test "owner can delete all events of a type" do
    sign_in_as(@owner)

    assert_difference -> { @sink.events.where(event_type: @event_type).count }, -3 do
      delete sink_event_type_path(@sink, @event_type), as: :turbo_stream
    end

    assert_response :success
  end

  test "admin can delete all events of a type" do
    sign_in_as(@admin)

    assert_difference -> { @sink.events.where(event_type: @event_type).count }, -3 do
      delete sink_event_type_path(@sink, @event_type), as: :turbo_stream
    end

    assert_response :success
  end

  test "regular member CANNOT delete events of a type" do
    sign_in_as(@member)

    assert_no_difference "@sink.events.count" do
      delete sink_event_type_path(@sink, @event_type)
    end

    assert_response :forbidden
  end
end
