class CreateCargoGuias < ActiveRecord::Migration[8.0]
  def change
    create_table :cargo_guias do |t|
      t.string :nome_do_cargo
      t.references :filtro, null: false, foreign_key: true

      t.timestamps
    end
  end
end
