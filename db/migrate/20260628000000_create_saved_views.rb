class CreateSavedViews < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_views do |t|
      t.references :sink, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :event_type
      t.date :event_date
      t.string :property_key
      t.string :property_op
      t.string :property_value

      t.timestamps
    end

    add_index :saved_views, [ :user_id, :sink_id, :name ], unique: true
    add_index :saved_views, [ :sink_id, :user_id ]
  end
end
