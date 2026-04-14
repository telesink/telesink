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

    sink2 = user.sinks.create!(name: "Newer Sink", account: accounts(:telebugs))
    sink1 = user.sinks.create!(name: "Older Sink", created_at: 1.day.ago, account: accounts(:telebugs))

    assert_equal [ sink1, sink2 ], user.sinks.to_a
  end

  test "ordered_by_role orders by role descending (owner first) then by nickname ascending" do
    account = accounts(:telebugs)

    common = { password: "password123", account: account }

    owner_z = User.create!(common.merge(nickname: "Zoe", email_address: "zoe@test.com", role: :owner))
    owner_a = User.create!(common.merge(nickname: "Alice", email_address: "alice@test.com", role: :owner))
    admin = User.create!(common.merge(nickname: "Mike", email_address: "mike@test.com", role: :admin))
    member_b = User.create!(common.merge(nickname: "Bob", email_address: "bob@test.com", role: :member))
    member_a = User.create!(common.merge(nickname: "Anna", email_address: "anna@test.com", role: :member))

    expected = [ owner_a, owner_z, admin, member_a, member_b ]

    assert_equal(
      expected,
      User.where(id: [ owner_z, owner_a, admin, member_b, member_a ].map(&:id)).ordered_by_role
    )
  end
end
