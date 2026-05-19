class AddFiltrosToCadernos < ActiveRecord::Migration[8.0]
  def change
    add_column :cadernos, :filtros, :json
  end
end
