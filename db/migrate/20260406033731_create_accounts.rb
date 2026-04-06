class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :join_code

      t.timestamps
    end

    add_index :accounts, :join_code, unique: true
  end
end
