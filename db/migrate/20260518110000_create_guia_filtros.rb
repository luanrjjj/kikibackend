class CreateGuiaFiltros < ActiveRecord::Migration[8.0]
  def change
    create_table :guia_filtros do |t|
      t.references :guia, null: false, foreign_key: { to_table: :guias }
      t.references :filtro, null: false, foreign_key: true

      t.timestamps
    end
  end
end
