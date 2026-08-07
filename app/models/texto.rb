class Texto < ApplicationRecord
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  has_many :questaos

  validates :texto, presence: true
  validates :prova_id, presence: true
  validates :concurso_id, presence: true

  before_validation :set_concurso_from_prova

  private

  def set_concurso_from_prova
    if prova_id.present? && concurso_id.blank?
      self.concurso_id = prova&.concurso_id
    end
  end
end
