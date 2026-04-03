class Export < ApplicationRecord
  belongs_to :user
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true

  validates :questoes_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
