class MakeEventTextRequired < ActiveRecord::Migration[8.1]
  def change
    change_column_null :events, :text, false
  end
end
