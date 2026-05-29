class CargoGuia < ApplicationRecord
  self.table_name = "cargo_guias"

  belongs_to :filtro
  has_many :guia_filtros, dependent: :nullify
end
