class AddHasUnreadEventsToSinkMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :sink_memberships, :has_unread_events, :boolean, default: false, null: false
  end
end
