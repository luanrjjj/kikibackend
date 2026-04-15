class CreateCadernos < ActiveRecord::Migration[8.0]
  def up
    create_table :cadernos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :prova, null: true, foreign_key: true
      t.references :concurso, null: true, foreign_key: true
      t.json :questoes_ids, default: []
      t.string :nome, null: false
      t.string :nome_da_pasta, null: false

      t.timestamps
    end

    add_index :cadernos, [:user_id, :nome], unique: true
    add_index :cadernos, [:user_id, :nome_da_pasta], unique: true
  end

  def down
    execute "DROP TABLE IF EXISTS cadernos CASCADE;"
  end
end
