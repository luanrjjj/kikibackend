class AddFiltroRefToCadernos < ActiveRecord::Migration[8.0]
  def change
    add_reference :cadernos, :filtro, null: true, foreign_key: true
  end
end
