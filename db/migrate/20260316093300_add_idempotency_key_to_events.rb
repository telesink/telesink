class AddIdempotencyKeyToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :idempotency_key, :string

    add_index :events, [ :sink_id, :idempotency_key ],
              unique: true,
              name: "index_events_on_sink_id_and_idempotency_key"
  end
end
