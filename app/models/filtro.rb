class Filtro < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cadernos, dependent: :nullify
  has_many :guia_filtros, dependent: :destroy
  has_many :guias, through: :guia_filtros
end
