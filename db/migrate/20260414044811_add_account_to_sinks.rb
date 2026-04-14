class AddAccountToSinks < ActiveRecord::Migration[8.1]
  def change
    add_reference :sinks, :account, foreign_key: true, null: true, index: true

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE sinks
          SET account_id = COALESCE(
            (
              SELECT users.account_id
              FROM users
              INNER JOIN sink_memberships
                ON sink_memberships.user_id = users.id
              WHERE sink_memberships.sink_id = sinks.id
              LIMIT 1
            ),
            (SELECT id FROM accounts ORDER BY id ASC LIMIT 1)
          )
          WHERE account_id IS NULL;
        SQL
      end
    end

    change_column_null :sinks, :account_id, false
  end
end
