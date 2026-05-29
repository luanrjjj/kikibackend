class GuiaFiltro < ApplicationRecord
  self.table_name = "guia_filtros"

  belongs_to :guia
  belongs_to :filtro
  belongs_to :cargo_guia, optional: true
end
