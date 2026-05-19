class Guia < ApplicationRecord
  belongs_to :concurso
  has_many :guia_filtros, dependent: :destroy
  has_many :filtros, through: :guia_filtros

  validates :nome, presence: true
end
