require "test_helper"

class SinkTest < ActiveSupport::TestCase
  test "generates a secure token" do
    sink = Sink.new
    assert_not_nil sink.token
    assert_equal 24, sink.token.length
  end

  test "builds a default 'all events' column on creation when none exist" do
    sink = Sink.new
    sink.valid?

    assert_equal 1, sink.columns.size
    assert_equal "all events", sink.columns.first.name
  end

  test "does not build default column if columns already present" do
    sink = Sink.new
    sink.columns.build(name: "My Custom Column")
    sink.valid?

    assert_equal 1, sink.columns.size
    assert_equal "My Custom Column", sink.columns.first.name
  end
end
