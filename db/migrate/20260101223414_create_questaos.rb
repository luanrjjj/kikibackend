class CreateQuestaos < ActiveRecord::Migration[8.0]
  def change
    create_table :questaos do |t|
      t.text :texto
      t.boolean :discursiva, null: false
      t.date :anulada
      t.date :desatualizada
      t.integer :ano, null: false
      t.json :alternativas
      t.string :correta
      t.string :enunciado, null:false
      t.references :prova, index: true, null: false, foreign_key: true
      t.references :concurso, index: true,  foreign_key: true
      t.references :assunto, index: true, foreign_key: true
      t.references :disciplina, index: true, foreign_key: true
      t.timestamps
    end
  end
end
