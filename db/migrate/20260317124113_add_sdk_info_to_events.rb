class AddSdkInfoToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :sdk_name, :string
    add_column :events, :sdk_version, :string
  end
end
