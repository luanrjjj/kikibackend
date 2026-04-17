class Caderno < ApplicationRecord
  belongs_to :user
  belongs_to :prova, optional: true
  has_many :resolucoes, class_name: 'Resolucao', dependent: :nullify

  validates :questoes_ids, presence: true
end
