require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "accepts valid emails" do
    valid_emails = [
      "user@example.com",
      "user.name+tag@example.co.uk",
      "user_name123@sub.domain.example.com",
      "user+tag@sub.example.com.ua"
    ]

    valid_emails.each do |email|
      user = User.new(email_address: email, password: "password123", account: accounts(:telebugs))
      assert user.valid?, "Expected #{email} to be a valid email"
    end
  end

  test "rejects invalid emails" do
    invalid_emails = [
      "plainaddress",
      "@missinguser.com",
      "user@.com",
      "user@com.",
      "user name@example.com",
      "user@exam ple.com",
      "user@@example.com"
    ]

    invalid_emails.each do |email|
      user = User.new(email_address: email, password: "password123", account: accounts(:telebugs))
      refute user.valid?, "Expected #{email} to be invalid"
      assert_includes user.errors[:email_address], "is invalid"
    end
  end

  test "normalizes on assignment" do
    user = User.new(email_address: "  DOWNCASED@EXAMPLE.COM  ", password: "password123", account: accounts(:telebugs))
    assert_equal "downcased@example.com", user.email_address
  end

  test "derives nickname from email if not provided" do
    user = User.new(email_address: "sunshine@telesink.com", password: "password123", account: accounts(:telebugs))

    assert_equal "sunshine", user.nickname

    assert user.valid?
  end

  test "does NOT override a manually provided nickname" do
    user = User.new(
      email_address: "sunshine@telesink.com",
      nickname: "customnick",
      password: "password123",
      account: accounts(:telebugs)
    )

    assert user.valid?
    assert_equal "customnick", user.nickname
  end

  test "nickname is required" do
    user_with_email = User.new(email_address: "test@example.com", password: "password123", account: accounts(:telebugs))
    assert user_with_email.valid?

    user_without_email = User.new(password: "password123", account: accounts(:telebugs))
    refute user_without_email.valid?
    assert_includes user_without_email.errors[:nickname], "can't be blank"
  end

  test "nickname is ONLY derived on create" do
    user = User.create!(
      email_address: "oldname@telesink.com",
      password: "password123",
      account: accounts(:telebugs)
    )
    assert_equal "oldname", user.nickname

    user.update!(email_address: "newname@telesink.com")
    assert_equal "oldname", user.nickname
  end

  test "hashes the password" do
    user = User.new(email_address: "secure@telesink.com", password: "pass", account: accounts(:telebugs))
    user.save!
    assert user.authenticate("pass")
    refute user.authenticate("wrong")
    assert_not_nil user.password_digest
  end

  test "sinks are ordered by created_at ascending" do
    user = User.create!(email_address: "order@test.com", password: "password123", account: accounts(:telebugs))
    sink2 = user.sinks.create!(name: "Newer Sink")
    sink1 = user.sinks.create!(name: "Older Sink", created_at: 1.day.ago)
    assert_equal [ sink1, sink2 ], user.sinks.to_a
  end
end
