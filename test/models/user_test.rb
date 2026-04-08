require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "subscribed? returns true for admins" do
    user = User.new(admin: true)
    assert user.subscribed?
  end

  test "subscribed? returns true for active subscriptions within period" do
    user = User.new(
      admin: false,
      subscription_status: "active",
      current_period_end: 1.day.from_now
    )
    assert user.subscribed?
  end

  test "subscribed? returns false for inactive subscriptions" do
    user = User.new(
      admin: false,
      subscription_status: "INACTIVE",
      current_period_end: 1.day.from_now
    )
    assert_not user.subscribed?
  end

  test "subscribed? returns false for expired subscriptions" do
    user = User.new(
      admin: false,
      subscription_status: "ACTIVE",
      current_period_end: 1.day.ago
    )
    assert_not user.subscribed?
  end

  test "subscribed? returns false if current_period_end is missing" do
    user = User.new(
      admin: false,
      subscription_status: "ACTIVE",
      current_period_end: nil
    )
    assert_not user.subscribed?
  end

  test "can_export? returns true for free users with less than 3 exports this month" do
    user = User.create!(email: "test_export@example.com", password: "password")
    user.exports.create!(questoes_count: 10, created_at: Time.current)
    user.exports.create!(questoes_count: 5, created_at: Time.current)
    
    assert_not user.subscribed?
    assert_equal 2, user.monthly_exports_count
    assert user.can_export?
  end

  test "can_export? returns false for free users with 3 or more exports this month" do
    user = User.create!(email: "limit@example.com", password: "password")
    3.times { user.exports.create!(questoes_count: 5, created_at: Time.current) }
    
    assert_not user.subscribed?
    assert_equal 3, user.monthly_exports_count
    assert_not user.can_export?
  end

  test "can_export? returns true for subscribed users even with many exports" do
    user = User.create!(
      email: "sub@example.com", 
      password: "password",
      subscription_status: "ACTIVE",
      current_period_end: 1.month.from_now
    )
    5.times { user.exports.create!(questoes_count: 5, created_at: Time.current) }
    
    assert user.subscribed?
    assert user.can_export?
  end
end
