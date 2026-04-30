class Prova < ApplicationRecord
  belongs_to :orgao
  belongs_to :banca
  belongs_to :concurso

  has_many :prova_questaos, dependent: :destroy
  has_many :questaos, through: :prova_questaos
  has_many :comentarios, dependent: :destroy
  has_many :textos, dependent: :destroy
  has_many :cadernos, dependent: :nullify

  validates :nome, presence: true

  # enum escolaridade: {
  #   "Ensino Fundamental": 0,
  #   "Ensino Médio": 1,
  #   "Ensino Superior": 2,
  #   "Mestrado": 3,
  #   "Doutorado": 4
  # }

end