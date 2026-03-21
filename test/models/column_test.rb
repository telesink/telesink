require "test_helper"

class ColumnTest < ActiveSupport::TestCase
  test "filters returns empty hash when config is nil" do
    columns(:all_telebugs).update!(config: nil)
    assert_equal({}, columns(:all_telebugs).filters)
  end

  test "filters returns the filters hash" do
    columns(:all_telebugs).update!(config: {
      "filters" => {
        "event_types" => [ "user.signup" ],
        "search" => "premium"
      }
    })

    filters = { "event_types" => [ "user.signup" ], "search" => "premium" }
    assert_equal filters, columns(:all_telebugs).filters
  end

  test "event_types returns array (handles missing key)" do
    columns(:all_telebugs).update!(config: { "filters" => {} })

    assert_equal [], columns(:all_telebugs).event_types
  end

  test "search_term returns stripped string or nil" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "search" => "   premium   " }
    })
    assert_equal "premium", columns(:all_telebugs).search_term

    columns(:all_telebugs).update!(config: {
      "filters" => { "search" => "   " }
    })
    assert_nil columns(:all_telebugs).search_term
  end

  test "recent_events applies filters and respects limit" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "search" => "premium" }
    })

    events = columns(:all_telebugs).recent_events(limit: 2)
    assert_equal 2, events.size
    assert events.all? { |e| e.text.downcase.include?("premium") }
  end

  test "recent_events defaults to limit 30" do
    columns(:all_telebugs).update!(config: { "filters" => {} })

    events = columns(:all_telebugs).recent_events
    assert_equal 6, events.size
  end

  test "matches_event? returns true only for events that pass all filters" do
    columns(:all_telebugs).update!(config: {
      "filters" => {
        "event_types" => [ "user.signup" ],
        "search" => "premium"
      }
    })

    matching = Event.new(
      sink_id: columns(:all_telebugs).sink_id,
      event_type: "user.signup",
      text: "Premium user joined",
    )
    wrong_type = Event.new(
      sink_id: columns(:all_telebugs).sink_id,
      event_type: "user.login",
      text: "Premium user joined"
    )
    wrong_search = Event.new(
      sink_id: columns(:all_telebugs).sink_id,
      event_type: "user.signup",
      text: "Free user"
    )
    wrong_sink = Event.new(
      sink_id: 999,
      event_type: "user.signup",
      text: "Premium user joined"
    )

    assert columns(:all_telebugs).matches_event?(matching)
    assert_not columns(:all_telebugs).matches_event?(wrong_type)
    assert_not columns(:all_telebugs).matches_event?(wrong_search)
    assert_not columns(:all_telebugs).matches_event?(wrong_sink)
  end

  test "matches_event? matches everything when filters are empty" do
    columns(:all_telebugs).update!(config: { "filters" => {} })

    event = Event.new(
      sink_id: columns(:all_telebugs).sink_id,
      event_type: "anything",
      text: "whatever"
    )

    assert columns(:all_telebugs).matches_event?(event)
  end
end
