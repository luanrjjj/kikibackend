class CreateAssuntos < ActiveRecord::Migration[8.0]
  def change
    create_table :assuntos do |t|
      t.string :nome, null: false
      t.references :disciplina, index: true, null: false, foreign_key: true
      t.timestamps
    end
  end
end
