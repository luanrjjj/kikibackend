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

  test "can_export? permite 1 exportação por semana no plano gratuito" do
    user = User.create!(email: "test_export_#{SecureRandom.hex(4)}@example.com", password: "password")
    assert_equal :free, user.plano_nivel
    assert_equal 1, user.limite_exportacoes_semana
    assert user.can_export?

    user.exports.create!(questoes_count: 10, created_at: Time.current)
    assert_not user.reload.can_export?

    user.exports.update_all(created_at: 8.days.ago)
    assert user.reload.can_export?
  end

  test "can_export? é ilimitado para assinantes" do
    user = User.create!(
      email: "sub_#{SecureRandom.hex(4)}@example.com",
      password: "password",
      plan: "BASIC",
      subscription_status: "ACTIVE",
      current_period_end: 1.month.from_now
    )
    5.times { user.exports.create!(questoes_count: 5, created_at: Time.current) }

    assert_nil user.limite_exportacoes_semana
    assert user.can_export?
  end
end
