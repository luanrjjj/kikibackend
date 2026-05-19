class CreateGuias < ActiveRecord::Migration[8.0]
  def change
    create_table :guias do |t|
      t.references :concurso, null: false, foreign_key: true
      t.string :nome, null: false

      t.timestamps
    end
  end
end
