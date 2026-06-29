class AddNomeToGuiaFiltros < ActiveRecord::Migration[8.0]
  def change
    add_column :guia_filtros, :nome, :string
  end
end
