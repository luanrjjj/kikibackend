class CreateQuestaos < ActiveRecord::Migration[8.0]
  def change
    create_table :questaos do |t|
      t.boolean :discursiva, null: false
      t.date :anulada
      t.date :desatualizada
      t.integer :ano, null: false
      t.json :alternativas
      t.string :correta
      t.string :enunciado, null:false
      t.integer :numero_questao, null:false
      t.string :sistema_ref_id
      t.string :real_id, null: false
      t.references :prova, index: true, null: false, foreign_key: true
      t.references :concurso, index: true,  foreign_key: true
      t.references :assunto, index: true, foreign_key: true
      t.references :disciplina, index: true, foreign_key: true
      t.references :texto, index: true, foreign_key: true
      t.timestamps
    end
    execute "ALTER SEQUENCE questaos_id_seq RESTART WITH 14007;"
  end
end
