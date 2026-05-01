class Caderno < ApplicationRecord
  belongs_to :user
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  belongs_to :pasta_caderno

  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy

  before_validation :set_default_pasta, on: :create
  before_create :populate_questoes_from_prova

  validates :nome, presence: true, uniqueness: { scope: :user_id }
  validates :pasta_caderno_id, presence: true

  private

  def set_default_pasta
    return if pasta_caderno_id.present?
    
    default_pasta = user.pasta_cadernos.find_or_create_by!(nome: 'Meus Cadernos')
    self.pasta_caderno_id = default_pasta.id
  end

  def populate_questoes_from_prova
    if prova_id.present? && questoes_ids.blank?
      self.questoes_ids = prova.questaos.joins(:prova_questaos).order('prova_questaos.numero_questao ASC').pluck(:id)
    end
  end
end
