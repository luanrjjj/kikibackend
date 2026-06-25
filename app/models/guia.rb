class Guia < ApplicationRecord
  self.table_name = "guias"

  belongs_to :concurso
  has_many :guia_filtros, dependent: :destroy
  has_many :cargo_guias, -> { distinct }, through: :guia_filtros

  def filtros
    if guia_filtros.loaded?
      (guia_filtros.map(&:filtro) + guia_filtros.map(&:filtro_2) + guia_filtros.map(&:filtro_3)).compact.uniq
    else
      filter_ids = guia_filtros.pluck(:filtro_id_1, :filtro_id_2, :filtro_id_3).flatten.compact.uniq
      Filtro.where(id: filter_ids)
    end
  end

  def filtro_ids
    guia_filtros.pluck(:filtro_id_1, :filtro_id_2, :filtro_id_3).flatten.compact.uniq
  end

  def filtro_ids=(ids)
    guia_filtros.destroy_all
    Array(ids).compact.uniq.each do |id|
      guia_filtros.create!(filtro_id_1: id)
    end
  end

  validates :nome, presence: true
end
