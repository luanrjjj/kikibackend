class CreateComentarios < ActiveRecord::Migration[8.0]
  def change
    create_table :comentarios do |t|
      t.references :prova, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :concurso, null: true, foreign_key: true
      t.references :questao, null: false, foreign_key: true
      t.integer :votos_soma, default: 0

      t.timestamps
    end
  end
end
