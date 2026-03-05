class AddEmojiToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :emoji, :string, limit: 8, null: true
  end
end
