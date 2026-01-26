class Prova < ApplicationRecord
  belongs_to :orgao
  belongs_to :banca
  belongs_to :concurso

  has_many :questaos
  has_many :textos

  validates :nome, presence: true

  # enum escolaridade: {
  #   "Ensino Fundamental": 0,
  #   "Ensino Médio": 1,
  #   "Ensino Superior": 2,
  #   "Mestrado": 3,
  #   "Doutorado": 4
  # }

end