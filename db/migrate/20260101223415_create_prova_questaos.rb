class CreateProvaQuestaos < ActiveRecord::Migration[8.0]
  def change
    create_table :prova_questaos do |t|
      t.references :prova, null: false, foreign_key: true
      t.references :questao, null: false, foreign_key: true
      t.integer :numero_questao, null: false

      t.timestamps
    end
    add_index :prova_questaos, [:prova_id, :questao_id], unique: true
  end
end
