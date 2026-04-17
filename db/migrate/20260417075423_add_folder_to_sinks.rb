class AddFolderToSinks < ActiveRecord::Migration[8.1]
  def change
    add_reference :sinks, :folder, foreign_key: true, null: true
  end
end
