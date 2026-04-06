class AddAccountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :account, foreign_key: true, null: true, index: true
  end
end
