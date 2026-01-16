class Prova < ApplicationRecord
  belongs_to :orgao
  belongs_to :banca
  belongs_to :concurso

  has_many :questaos
  has_many :textos

  validates :nome, presence: true
end