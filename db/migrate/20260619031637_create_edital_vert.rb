class CreateEditalVert < ActiveRecord::Migration[8.0]
  def change
    create_table :edital_vert do |t|
      t.references :concurso, null: true, foreign_key: true
      t.string :cargo
      t.references :prova, null: true, foreign_key: true
      t.json :texto_json_disciplina
      t.text :texto_verticalizado

      t.timestamps
    end
  end
end
