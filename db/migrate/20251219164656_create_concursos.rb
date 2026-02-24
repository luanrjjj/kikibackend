class CreateConcursos < ActiveRecord::Migration[8.0]
  def change
    create_table :concursos do |t|
      t.string :nome
      t.date :inscricoes_ate
      t.string :edital_nome
      t.json :cargos
      t.references :banca, index: true, foreign_key: true
      t.references :orgao, index: true, foreign_key: true
      t.timestamps
    end
    execute "ALTER SEQUENCE concursos_id_seq RESTART WITH 14007;"

  end
end
