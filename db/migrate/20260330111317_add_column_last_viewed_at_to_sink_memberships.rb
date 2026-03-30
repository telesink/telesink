class AddColumnLastViewedAtToSinkMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :sink_memberships, :column_last_viewed_at, :jsonb, default: {}, null: false
  end
end
