class Session < ApplicationRecord
  belongs_to :user
  before_create :generate_token

  private

  def generate_token
    self.token = SecureRandom.hex(24)
  end
end