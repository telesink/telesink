class SetDefaultEmojiToPushpin < ActiveRecord::Migration[8.1]
  def change
    change_column_default :events, :emoji, from: nil, to: "📌"
    change_column_null :events, :emoji, false

    reversible do |dir|
      dir.up do
        Event.where(emoji: nil).update_all(emoji: "📌")
      end
    end
  end
end
