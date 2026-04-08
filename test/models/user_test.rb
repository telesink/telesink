require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ", account: accounts(:telebugs))

    assert_equal "downcased@example.com", user.email_address
  end

  test "nickname is derived from the email" do
    user = User.create(email_address: "sunshine@telesink.com", account: accounts(:telebugs))

    assert_equal "sunshine", user.nickname
  end

  test "hashes the password (via has_secure_password)" do
    user = User.new(email_address: "secure@telesink.com", password: "pass", account: accounts(:telebugs))
    user.save!

    assert user.authenticate("pass")
    refute user.authenticate("wrong")
    assert_not_nil user.password_digest
  end

  test "sinks are ordered by created_at ascending (oldest first)" do
    user = User.create!(email_address: "order@test.com", password: "password123", account: accounts(:telebugs))

    sink2 = user.sinks.create!(name: "Newer Sink")
    sink1 = user.sinks.create!(name: "Older Sink", created_at: 1.day.ago)

    assert_equal [ sink1, sink2 ], user.sinks.to_a
  end
end
