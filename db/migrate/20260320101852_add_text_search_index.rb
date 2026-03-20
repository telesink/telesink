class AddTextSearchIndex < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :events, :text,
              name: "index_events_on_text_trgm",
              using: :gin,
              opclass: :gin_trgm_ops
  end
end
