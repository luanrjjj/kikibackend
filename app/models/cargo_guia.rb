class CargoGuia < ApplicationRecord
  self.table_name = "cargo_guias"

  has_many :guia_filtros, dependent: :destroy
  has_one :guia, through: :guia_filtros

  def filtros
    ids = []
    if filtro_ids.is_a?(Array)
      filtro_ids.each do |item|
        if item.is_a?(Hash)
          item.each_value { |val| ids.concat(Array(val)) }
        else
          ids << item
        end
      end
    elsif filtro_ids.is_a?(Hash)
      filtro_ids.each_value { |val| ids.concat(Array(val)) }
    end
    Filtro.where(id: ids.compact.uniq.map(&:to_i))
  end

  def filtros_for_guia(guia)
    return Filtro.none unless guia

    ids = []
    if filtro_ids.is_a?(Array)
      filtro_ids.each do |item|
        if item.is_a?(Hash) && item.key?(guia.nome)
          ids.concat(Array(item[guia.nome]))
        elsif !item.is_a?(Hash)
          ids << item
        end
      end
    elsif filtro_ids.is_a?(Hash) && filtro_ids.key?(guia.nome)
      ids.concat(Array(filtro_ids[guia.nome]))
    end

    # Fallback to legacy format if no guide-specific entry was found
    if ids.empty? && filtro_ids.is_a?(Array) && filtro_ids.all? { |x| !x.is_a?(Hash) }
      ids = filtro_ids
    end

    Filtro.where(id: ids.compact.uniq.map(&:to_i))
  end
end
