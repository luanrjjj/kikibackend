class GuiaFiltro < ApplicationRecord
  self.table_name = "guia_filtros"

  belongs_to :guia
  belongs_to :cargo_guia, optional: true

  belongs_to :filtro, class_name: "Filtro", foreign_key: "filtro_id_1", optional: true
  belongs_to :filtro_2, class_name: "Filtro", foreign_key: "filtro_id_2", optional: true
  belongs_to :filtro_3, class_name: "Filtro", foreign_key: "filtro_id_3", optional: true

  validates :nome, presence: true
  validates :filtro_id_1, presence: true
end
