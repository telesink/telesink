require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "accounts generate join codes upon creation" do
    account = Account.create!

    assert_not account.join_code.nil?
    assert_equal 14, account.join_code.size
  end

  test "accounts can reset join code" do
    account = Account.create!
    original_join_code = account.join_code

    account.reset_join_code

    assert_not_equal original_join_code, account.join_code
    assert_equal 14, account.join_code.size
  end
end
