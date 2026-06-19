class AddMoreFiltrosToCadernos < ActiveRecord::Migration[8.0]
  def change
    add_column :cadernos, :filtro_id_2, :bigint
    add_column :cadernos, :filtros_2, :json
    add_column :cadernos, :filtros_id_3, :bigint
    add_column :cadernos, :filtros_3, :json

    add_index :cadernos, :filtro_id_2
    add_index :cadernos, :filtros_id_3
    add_foreign_key :cadernos, :filtros, column: :filtro_id_2
    add_foreign_key :cadernos, :filtros, column: :filtros_id_3
  end
end
