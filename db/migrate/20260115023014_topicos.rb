class Topicos < ActiveRecord::Migration[8.0]
  def change
    create_table :topicos do |t|
      t.string :nome, null: false
      t.references :disciplina, index: true, foreign_key: true
      t.references :assunto, index: true, foreign_key: true
      t.timestamps
    end
  end
end