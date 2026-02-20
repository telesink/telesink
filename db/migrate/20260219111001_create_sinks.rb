class CreateSinks < ActiveRecord::Migration[8.1]
  def change
    create_table :sinks do |t|
      t.string :name, null: false, index: true

      t.timestamps
    end
  end
end
