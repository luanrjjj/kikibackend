class Caderno < ApplicationRecord
  belongs_to :user
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  belongs_to :pasta_caderno

  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy

  validates :nome, presence: true, uniqueness: { scope: :user_id }
  validates :pasta_caderno_id, presence: true
end
