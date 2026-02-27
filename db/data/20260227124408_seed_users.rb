require 'bcrypt'

class SeedUsers < SeedMigration::Migration
  def up
    puts "Creating 4 users with specific roles and subscription statuses..."

    # Generate password hashes
    admin_password_hash = BCrypt::Password.create('password')
    user_password_hash = BCrypt::Password.create('password')

    # User 1: Admin with active subscription
    User.find_or_create_by!(email: 'admin@example.com') do |user|
      user.password_digest = admin_password_hash
      user.name = 'Admin User'
      user.subscription_status = 'active'
      user.admin = true
    end

    # User 2: Regular user with active subscription
    User.find_or_create_by!(email: 'active_user@example.com') do |user|
      user.password_digest = user_password_hash
      user.name = 'Active Subscriber'
      user.subscription_status = 'active'
      user.admin = false
    end

    # User 3: Regular user with expired subscription
    User.find_or_create_by!(email: 'expired_user@example.com') do |user|
      user.password_digest = user_password_hash
      user.name = 'Expired Subscriber'
      user.subscription_status = 'expired'
      user.admin = false
    end

    # User 4: Regular user with no active subscription (default/inactive)
    User.find_or_create_by!(email: 'inactive_user@example.com') do |user|
      user.password_digest = user_password_hash
      user.name = 'Inactive User'
      user.subscription_status = 'inactive' # Or nil, depending on default behavior
      user.admin = false
    end

    puts "Successfully created/updated 4 users."
  end

  def down
    emails_to_delete = ['admin@example.com', 'active_user@example.com', 'expired_user@example.com', 'inactive_user@example.com']
    User.where(email: emails_to_delete).destroy_all
    puts "Successfully destroyed seeded users."
  end
end
