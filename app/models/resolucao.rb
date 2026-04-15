class Resolucao < ApplicationRecord
  belongs_to :user
  belongs_to :questao
  belongs_to :caderno, optional: true

  validates :resposta, presence: true
end
