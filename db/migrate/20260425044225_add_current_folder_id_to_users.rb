class AddCurrentFolderIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_folder_id, :bigint
    add_index :users, :current_folder_id
    add_foreign_key :users, :folders, column: :current_folder_id, on_delete: :nullify
  end
end
