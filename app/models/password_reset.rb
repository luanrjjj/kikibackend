class PasswordReset < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create

  def expired?
    expires_at < Time.current
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64
    self.expires_at ||= 2.hours.from_now
  end
end
