class CreateResolucoes < ActiveRecord::Migration[8.0]
  def up
    create_table :resolucaos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :questao, null: false, foreign_key: true
      t.references :caderno, null: true, foreign_key: true
      t.string :resposta
      t.boolean :correta

      t.timestamps
    end
  end

  def down
    execute "DROP TABLE IF EXISTS resolucaos CASCADE;"
  end
end
