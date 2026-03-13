class RenamePayloadToPropertiesInEvents < ActiveRecord::Migration[8.1]
  def change
    rename_column :events, :payload, :properties
  end
end
