class Texto < ApplicationRecord
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  has_many :questaos
  has_many :questaos_para_verificar, class_name: 'Questao', foreign_key: :text_to_verify, dependent: :nullify

  validates :texto, presence: true
  validates :prova_id, presence: true
  validates :concurso_id, presence: true

  before_validation :set_concurso_from_prova
  after_commit :expirar_cache_das_provas, on: %i[update destroy]

  private

  def expirar_cache_das_provas
    prova_ids = ProvaQuestao.where(questao_id: Questao.where(texto_id: id).select(:id)).distinct.pluck(:prova_id)
    Prova.expirar_cache_questaos(prova_ids)
  end

  def set_concurso_from_prova
    if prova_id.present? && concurso_id.blank?
      self.concurso_id = prova&.concurso_id
    end
  end
end
