class AddCargoGuiaToGuiaFiltros < ActiveRecord::Migration[8.0]
  def change
    add_reference :guia_filtros, :cargo_guia, null: true, foreign_key: { to_table: :cargo_guias }
  end
end
