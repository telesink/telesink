class CreateSinkMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :sink_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sink, null: false, foreign_key: true

      t.timestamps
    end

    add_index :sink_memberships, [ :user_id, :sink_id ], unique: true
  end
end
