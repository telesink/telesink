require "test_helper"

class SinkMembershipTest < ActiveSupport::TestCase
  test "last_viewed_at_for returns nil when the column has never been viewed" do
    column = Column.new(id: 999)

    assert_nil sink_memberships(:kyrylo_telebugs).last_viewed_at_for(column)
  end

  test "last_viewed_at_for returns a Time object when the column has been viewed" do
    column = Column.new(id: 42)

    sink_memberships(:kyrylo_telebugs).column_last_viewed_at = { "42" => "2026-04-20T14:30:00Z" }
    sink_memberships(:kyrylo_telebugs).save!

    result = sink_memberships(:kyrylo_telebugs).last_viewed_at_for(column)
    assert_kind_of ActiveSupport::TimeWithZone, result
    assert_equal Time.zone.parse("2026-04-20T14:30:00Z"), result
  end

  test "last_viewed_at_for gracefully handles invalid timestamp strings" do
    column = Column.new(id: 1)

    sink_memberships(:kyrylo_telebugs).column_last_viewed_at = { "1" => "not-a-time" }
    sink_memberships(:kyrylo_telebugs).save!

    assert_nil sink_memberships(:kyrylo_telebugs).last_viewed_at_for(column)
  end

  test "mark_all_columns_viewed updates timestamps for every column in the sink" do
    sink = sinks(:telebugs)

    # ensure the sink has columns
    sink.columns.destroy_all
    col1 = sink.columns.create!(name: "Column 1", position: 1)
    col2 = sink.columns.create!(name: "Column 2", position: 2)

    travel_to Time.zone.parse("2026-04-20 15:00:00 UTC") do
      sink_memberships(:kyrylo_telebugs).mark_all_columns_viewed
    end

    sink_memberships(:kyrylo_telebugs).reload

    assert_equal "2026-04-20T15:00:00Z", sink_memberships(:kyrylo_telebugs).column_last_viewed_at[col1.id.to_s]
    assert_equal "2026-04-20T15:00:00Z", sink_memberships(:kyrylo_telebugs).column_last_viewed_at[col2.id.to_s]
  end

  test "mark_all_columns_viewed saves the record" do
    assert_changes -> { sink_memberships(:kyrylo_telebugs).updated_at } do
      sink_memberships(:kyrylo_telebugs).mark_all_columns_viewed
    end
  end
end
