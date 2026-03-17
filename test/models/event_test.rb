# test/models/event_test.rb
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
end
