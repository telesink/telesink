require "test_helper"

class Telesink::EventTest < ActiveSupport::TestCase
  test "event defaults to 'event'" do
    assert_equal "event", Telesink::Event.new({}).event_type
    assert_equal "user_joined", Telesink::Event.new(event: "user_joined").event_type
  end

  test "emoji defaults to 📌" do
    assert_equal "📌", Telesink::Event.new({}).emoji
    assert_equal "🚀", Telesink::Event.new(emoji: "🚀").emoji
  end

  test "text returns nil when missing or blank (no longer defaults to empty string)" do
    assert_nil Telesink::Event.new({}).text
    assert_nil Telesink::Event.new(text: "").text
    assert_nil Telesink::Event.new(text: "   ").text
    assert_equal "Hello there", Telesink::Event.new(text: "Hello there").text
  end

  test "properties defaults to empty hash" do
    with_properties = Telesink::Event.new(
      properties: { score: 100 },
      event: "game"
    )
    assert_equal({ score: 100 }, with_properties.properties)

    without_properties = Telesink::Event.new(event_type: "click")
    assert_equal({}, without_properties.properties)
  end

  test "occurred_at parses string or defaults to Time.current" do
    event = Telesink::Event.new(occurred_at: "2026-03-11 12:00:00 UTC")
    assert_equal Time.parse("2026-03-11 12:00:00 UTC"), event.occurred_at

    event = Telesink::Event.new({})
    assert_in_delta Time.current, event.occurred_at, 1.second
  end

  test "is invalid without text" do
    event = Telesink::Event.new(event_type: "test")
    refute event.valid?
    assert_equal [ "Text can't be blank" ], event.errors.full_messages
  end

  test "is valid with text" do
    event = Telesink::Event.new(text: "Anything")
    assert event.valid?
  end
end
