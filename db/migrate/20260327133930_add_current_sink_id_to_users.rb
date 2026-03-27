class AddCurrentSinkIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_sink_id, :bigint
    add_index :users, :current_sink_id
    add_foreign_key :users, :sinks, column: :current_sink_id, on_delete: :nullify
  end
end
