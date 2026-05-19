class CreateFiltros < ActiveRecord::Migration[8.0]
  def change
    create_table :filtros do |t|
      t.references :user, null: true, foreign_key: true
      t.json :filtro
      t.string :nome_do_filtro

      t.timestamps
    end
  end
end
