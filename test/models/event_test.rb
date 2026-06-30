require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "validates presence of event_type and text" do
    event = Event.new(sink: sinks(:telebugs))

    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
    assert_includes event.errors[:text], "can't be blank"
  end

  test "allows nil idempotency_key" do
    event = Event.new(
      sink: sinks(:telebugs),
      event_type: "user.signed_up",
      text: "New user signed up",
      idempotency_key: nil
    )

    assert event.valid?
  end

  test "enforces maximum length on idempotency_key" do
    event = Event.new(
      sink: sinks(:telebugs),
      event_type: "test",
      text: "test",
      idempotency_key: "x" * 256
    )

    assert_not event.valid?
    assert_includes event.errors[:idempotency_key], "is too long (maximum is 255 characters)"
  end

  test "idempotency_key must be unique per sink" do
    sink = sinks(:telebugs)
    key  = "user.signed_up:123"

    Event.create!(
      sink: sink,
      event_type: "user.signed_up",
      text: "New user",
      idempotency_key: key,
      occurred_at: Time.current,
    )

    duplicate = Event.new(
      sink: sink,
      event_type: "user.signed_up",
      text: "New user",
      idempotency_key: key,
      occurred_at: Time.current,
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key], "has already been taken"
  end

  test "belongs to a sink" do
    event = Event.new(
      event_type: "test",
      text: "test event"
    )

    assert_not event.valid?
    assert_includes event.errors[:sink], "must exist"
  end

  test "for_column returns all events when column has no filters" do
    columns(:all_telebugs).update!(config: { "filters" => {} })

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 6, events.size
  end

  test "for_column filters by single event_type" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "event_types" => [ "user.signup" ] }
    })

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 3, events.size
    assert events.all? { |e| e.event_type == "user.signup" }
  end

  test "for_column filters by multiple event_types" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "event_types" => [ "user.signup", "payment.succeeded" ] }
    })

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 4, events.size
  end

  test "for_column filters by search term" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "search" => "premium" }
    })

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 3, events.size
    assert events.all? { |e| e.text.downcase.include?("premium") }
  end

  test "for_column combines event_type + search filters" do
    columns(:all_telebugs).update!(config: {
      "filters" => {
        "event_types" => [ "user.signup" ],
        "search" => "premium"
      }
    })

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 1, events.size
    assert_equal events(:premium_signup), events.first
  end

  test "for_column handles nil config gracefully" do
    columns(:all_telebugs).update!(config: nil)

    events = Event.for_column(columns(:all_telebugs))
    assert_equal 6, events.size
  end

  test "for_column always orders by occurred_at DESC" do
    columns(:all_telebugs).update!(config: { "filters" => {} })

    events = Event.for_column(columns(:all_telebugs))
    times = events.map(&:occurred_at)
    assert_equal times.sort.reverse, times
  end

  test "Column#recent_events applies filters and respects limit" do
    columns(:all_telebugs).update!(config: {
      "filters" => { "search" => "premium" }
    })

    events = columns(:all_telebugs).recent_events(limit: 2)
    assert_equal 2, events.size
  end

  test "feed_batch search falls back for events without denormalized search text" do
    event = events(:new_signup)
    event.update_column(:search_text, nil)

    events = Event.feed_batch(sinks(:telebugs), search_query: "newuser@example.com")

    assert_includes events, event
  end
end
