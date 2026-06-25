class Filtro < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cadernos, dependent: :nullify
  has_many :guia_filtros, dependent: :destroy
  has_many :cargo_guias, dependent: :destroy

  def guias
    guia_ids = GuiaFiltro.where("filtro_id_1 = :id OR filtro_id_2 = :id OR filtro_id_3 = :id", id: id).pluck(:guia_id).uniq
    Guia.where(id: guia_ids)
  end
end
