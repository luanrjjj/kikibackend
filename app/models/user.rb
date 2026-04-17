class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :pagamentos, dependent: :destroy
  has_many :password_resets, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :cadernos, dependent: :destroy
  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def generate_password_reset_token!
    self.reset_password_token = SecureRandom.urlsafe_base64
    self.reset_password_sent_at = Time.current
    save!
  end

  def password_reset_period_valid?
    reset_password_sent_at > 2.hours.ago
  end

  def reset_password!(new_password)
    self.reset_password_token = nil
    self.password = new_password
    save!
  end

  def subscribed?
    admin? || (subscription_status&.upcase == "ACTIVE" && current_period_end.present? && current_period_end > Time.current)
  end

  def monthly_exports_count
    exports.where(created_at: Time.current.all_month).count
  end

  def can_export?
    subscribed? || monthly_exports_count < 3
  end

  def self.verify_admin_token(token)
    session = Session.includes(:user).find_by(token: token)

    return :unauthorized if session.nil? || session.expires_at < Time.current
    return :forbidden unless session.user.admin?
    :authorized
  end
end