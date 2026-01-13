class CreateQuestaos < ActiveRecord::Migration[8.0]
  def change
    create_table :questaos do |t|
      t.string :nome, null: false
      t.references :prova, index: true, null: false, foreign_key: true
      t.references :concurso, index: true, null: false, foreign_key: true
      t.references :assunto, index: true, null: false, foreign_key: true
      t.references :disciplina, index: true, null: false, foreign_key: true
      t.timestamps
    end
  end
end
