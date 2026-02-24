class AddValidadoAdminToTables < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :validado_admin, :datetime
    add_column :provas, :validado_admin, :datetime
    add_column :concursos, :validado_admin, :datetime
  end
end
