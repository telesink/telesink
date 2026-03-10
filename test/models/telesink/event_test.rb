require "test_helper"

class Telesink::EventTest < ActiveSupport::TestCase
  test "event_type defaults to 'message'" do
    assert_equal "event", Telesink::Event.new({}).event_type
    assert_equal "user_joined", Telesink::Event.new(event_type: "user_joined").event_type
  end

  test "emoji defaults to 📌" do
    assert_equal "📌", Telesink::Event.new({}).emoji
    assert_equal "🚀", Telesink::Event.new(emoji: "🚀").emoji
  end

  test "text" do
    assert_equal "Hello there", Telesink::Event.new(text: "Hello there").text
    assert_equal "", Telesink::Event.new({}).text
  end

  test "payload" do
    with_payload = Telesink::Event.new(
      payload: { score: 100 },
      event_type: "game",
      token: "abc"
    )
    assert_equal({ score: 100 }, with_payload.payload)

    without_payload = Telesink::Event.new(
      event_type: "click",
      token: "secret",
    )
    assert_equal({}, without_payload.payload)
  end

  test "occurred_at parses string or defaults to Time.current" do
    event = Telesink::Event.new(occurred_at: "2026-03-11 12:00:00 UTC")
    assert_equal Time.parse("2026-03-11 12:00:00 UTC"), event.occurred_at

    event = Telesink::Event.new({})
    assert_in_delta Time.current, event.occurred_at, 1.second
  end
end
