require "test_helper"

class ProcessEventJobTest < ActiveJob::TestCase
  test "creates a new event when there is no duplicate" do
    payload = {
      event: "user.signed_up",
      text: "New user signed up: alice@example.com",
      emoji: "👤",
      properties: { user_id: 123, plan: "pro" },
      idempotency_key: "unique-key-001",
      occurred_at: Time.current
    }

    assert_difference "Event.count", 1 do
      ProcessEventJob.perform_now(sinks(:telebugs), payload)
    end

    created_event = Event.last
    assert_equal "user.signed_up", created_event.event_type
    assert_equal "👤", created_event.emoji
    assert_equal({ "user_id" => 123, "plan" => "pro" }, created_event.properties)
    assert_equal "unique-key-001", created_event.idempotency_key
  end

  test "skips duplicate events with the same idempotency_key" do
    key = "payment-abc-789"

    Event.create!(
      sink: sinks(:telebugs),
      event_type: "payment.succeeded",
      text: "Payment received",
      idempotency_key: key,
      occurred_at: Time.current,
    )

    payload = {
      event: "payment.succeeded",
      text: "Payment received (retry)",
      idempotency_key: key,
      occurred_at: Time.current
    }

    assert_no_difference "Event.count" do
      ProcessEventJob.perform_now(sinks(:telebugs), payload)
    end
  end

  test "creates event when no idempotency_key is provided" do
    payload = {
      event: "order.created",
      text: "New order placed"
    }

    assert_difference "Event.count", 1 do
      ProcessEventJob.perform_now(sinks(:telebugs), payload)
    end

    created_event = Event.last
    assert_nil created_event.idempotency_key
  end

  test "uses occurred_at from payload when provided" do
    custom_time = Time.utc(2026, 3, 17, 12, 45, 30)

    payload = {
      event: "test.event",
      text: "Custom time test",
      occurred_at: custom_time.iso8601
    }

    ProcessEventJob.perform_now(sinks(:telebugs), payload)

    event = Event.last
    assert_equal custom_time, event.occurred_at
  end
end
