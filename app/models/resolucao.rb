class Resolucao < ApplicationRecord
  self.primary_key = [:id, :created_at]

  belongs_to :user
  belongs_to :questao
  belongs_to :caderno, optional: true

  validates :resposta, presence: true
end
