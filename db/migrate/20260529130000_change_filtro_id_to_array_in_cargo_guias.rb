class ChangeFiltroIdToArrayInCargoGuias < ActiveRecord::Migration[8.0]
  def change
    # Remove the old reference if it exists (it was created in a previous step)
    remove_reference :cargo_guias, :filtro, foreign_key: true, if_exists: true
    
    # Add the new array column using JSON (safe for PostgreSQL and flexible)
    add_column :cargo_guias, :filtro_ids, :json, default: []
  end
end
