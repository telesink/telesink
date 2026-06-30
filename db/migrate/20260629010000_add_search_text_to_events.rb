class AddSearchTextToEvents < ActiveRecord::Migration[8.1]
  class MigrationEvent < ApplicationRecord
    self.table_name = "events"
  end

  def up
    add_column :events, :search_text, :text

    say_with_time "Backfilling event search text" do
      MigrationEvent.reset_column_information

      MigrationEvent.find_each do |event|
        event.update_columns(search_text: search_text_for(event))
      end
    end

    change_column_null :events, :search_text, false

    add_index :events, :search_text,
              name: "index_events_on_search_text_trgm",
              using: :gin,
              opclass: :gin_trgm_ops
  end

  def down
    remove_index :events, name: "index_events_on_search_text_trgm"
    remove_column :events, :search_text
  end

  private

  def search_text_for(event)
    parts = [ event.event_type, event.text ]

    event.properties.each do |key, value|
      parts << key
      parts << searchable_property_value(value)
    end

    parts.compact.join(" ").squish
  end

  def searchable_property_value(value)
    case value
    when Hash, Array
      value.to_json
    else
      value.to_s
    end
  end
end
