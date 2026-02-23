class CreateBancas < ActiveRecord::Migration[8.0]
  def change
    create_table :bancas do |t|
      t.string :nome, null: false
      t.string :logo
      t.string :sigla, null: false
      t.integer :total_concursos
      t.timestamps
    end
    execute "ALTER SEQUENCE bancas_id_seq RESTART WITH 14007;"
  end
end
