class CreateTextos < ActiveRecord::Migration[8.0]
  def change
    create_table :textos do |t|
      t.string :texto, null: false
      t.references :prova, index: true, null: false, foreign_key: true
      t.references :concurso, index: true, null: false, foreign_key: true
      t.timestamps
    end
    execute "ALTER SEQUENCE textos_id_seq RESTART WITH 14007;"
  end
end
