class ProvaQuestao < ApplicationRecord
  belongs_to :prova
  belongs_to :questao

  validates :numero_questao, presence: true
  validates :questao_id, uniqueness: { scope: :prova_id }

  after_commit -> { Prova.expirar_cache_questaos(prova_id) }
end
