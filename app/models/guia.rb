class Guia < ApplicationRecord
  self.table_name = "guias"

  belongs_to :concurso
  has_many :guia_filtros, dependent: :destroy
  has_many :filtros, through: :guia_filtros

  validates :nome, presence: true
end
