class AddTokenToSinks < ActiveRecord::Migration[8.1]
  def change
    add_column :sinks, :token, :string
    add_index :sinks, :token, unique: true
  end
end
