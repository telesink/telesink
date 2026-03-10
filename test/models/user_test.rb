require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email_address
  end

  test "nickname is derived from the email" do
    user = User.new(email_address: "sunshine@telesink.com")
    assert_equal "sunshine", user.nickname
  end

  test "hashes the password (via has_secure_password)" do
    user = User.new(email_address: "secure@telesink.com", password: "pass")
    user.save!

    assert user.authenticate("pass")
    refute user.authenticate("wrong")
    assert_not_nil user.password_digest
  end
end
