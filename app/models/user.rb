class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def self.verify_admin_token(token)
    session = Session.includes(:user).find_by(token: token)

    return :unauthorized if session.nil? || session.expires_at < Time.current
    return :forbidden unless session.user.admin?
    :authorized
  end
end