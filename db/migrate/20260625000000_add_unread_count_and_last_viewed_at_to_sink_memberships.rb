class AddUnreadCountAndLastViewedAtToSinkMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :sink_memberships, :unread_count, :integer, default: 0, null: false
    add_column :sink_memberships, :last_viewed_at, :datetime
  end
end
