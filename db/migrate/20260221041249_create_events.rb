class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :sink, null: false, foreign_key: true

      t.string :event_type, null: false
      t.text :text
      t.datetime :occurred_at, null: false

      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :events, [ :sink_id, :occurred_at ], order: { occurred_at: :desc }
    add_index :events, :event_type
    add_index :events, :payload, using: :gin
  end
end
