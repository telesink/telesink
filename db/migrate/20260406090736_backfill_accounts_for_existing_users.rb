class BackfillAccountsForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    return if Account.exists?

    User.includes(:sinks).find_each do |user|
      account = Account.create!(
        join_code: SecureRandom.alphanumeric(12).scan(/.{4}/).join("-")
      )

      user.update_column(:account_id, account.id)
    end
  end

  def down
    User.update_all(account_id: nil)
    Account.delete_all
  end
end
