class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, null: false, default: 0

    User.reset_column_information
    User.update_all(role: :admin)
  end

  def down
    remove_column :users, :role
  end
end
