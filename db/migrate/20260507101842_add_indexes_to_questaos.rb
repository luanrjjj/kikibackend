class AddIndexesToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_index :questaos, :validado_admin
    add_index :questaos, :ano
    add_index :questaos, :anulada
    add_index :questaos, :desatualizada
    add_index :questaos, :correta
  end
end
