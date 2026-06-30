class AddUnreadCountAndLastViewedAtToSinkMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :sink_memberships, :unread_count, :integer, default: 0, null: false
    add_column :sink_memberships, :last_viewed_at, :datetime

    reversible do |dir|
      dir.up do
        update <<~SQL.squish
          UPDATE sink_memberships
          SET unread_count = 1
          WHERE has_unread_events = TRUE AND unread_count = 0
        SQL
      end
    end
  end
end
