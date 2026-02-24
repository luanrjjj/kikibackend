class CreateDisciplinas < ActiveRecord::Migration[8.0]
  def change
    create_table :disciplinas do |t|
      t.string :nome, null: false
      t.timestamps
    end
    execute "ALTER SEQUENCE disciplinas_id_seq RESTART WITH 14007;"

  end
end
