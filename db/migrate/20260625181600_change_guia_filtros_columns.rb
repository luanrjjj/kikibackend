class ChangeGuiaFiltrosColumns < ActiveRecord::Migration[8.0]
  def change
    # Rename column
    rename_column :guia_filtros, :filtro_id, :filtro_id_1

    # Change null constraint to allow null
    change_column_null :guia_filtros, :filtro_id_1, true

    # Add new columns
    add_column :guia_filtros, :filtro_id_2, :bigint, null: true
    add_column :guia_filtros, :filtro_id_3, :bigint, null: true

    # Add foreign keys
    add_foreign_key :guia_filtros, :filtros, column: :filtro_id_2
    add_foreign_key :guia_filtros, :filtros, column: :filtro_id_3

    # Add indexes
    add_index :guia_filtros, :filtro_id_2
    add_index :guia_filtros, :filtro_id_3
  end
end

