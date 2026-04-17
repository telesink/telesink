class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders do |t|
      t.string :name
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
