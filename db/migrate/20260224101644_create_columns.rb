class CreateColumns < ActiveRecord::Migration[8.1]
  def change
    create_table :columns do |t|
      t.references :sink, null: false, foreign_key: true

      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.jsonb :config

      t.timestamps
    end

    add_index :columns, [ :sink_id, :position ]
  end
end
