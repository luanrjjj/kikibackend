class Report < ApplicationRecord
  belongs_to :user
  belongs_to :questao

  validates :error_type, presence: true
  validates :description, presence: true, length: { maximum: 500 }
  validates :status, inclusion: { in: %w[pending resolved dismissed] }

  # Scopes for admin dashboard
  scope :pending, -> { where(status: 'pending') }
  scope :resolved, -> { where(status: 'resolved') }
end
