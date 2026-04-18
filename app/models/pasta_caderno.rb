class PastaCaderno < ApplicationRecord
  belongs_to :user
  has_many :cadernos, dependent: :destroy

  validates :nome, presence: true, uniqueness: { scope: :user_id }
end
