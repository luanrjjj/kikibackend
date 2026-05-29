class CargoGuia < ApplicationRecord
  self.table_name = "cargo_guias"

  has_many :guia_filtros, dependent: :destroy
  has_one :guia, through: :guia_filtros

  def filtros
    Filtro.where(id: Array(filtro_ids))
  end
end
