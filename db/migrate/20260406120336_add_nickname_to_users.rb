class AddNicknameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nickname, :string

    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.find_each do |user|
          user.update_column(:nickname, user.email_address.split("@").first)
        end
      end
    end
  end
end
