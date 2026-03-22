class AddHasEventsToColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :columns, :has_events, :boolean, default: false, null: false
  end
end
