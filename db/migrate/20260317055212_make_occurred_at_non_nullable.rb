class MakeOccurredAtNonNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :events, :occurred_at, false
  end
end
