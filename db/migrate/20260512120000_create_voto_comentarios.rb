class CreateVotoComentarios < ActiveRecord::Migration[8.0]
  def change
    create_table :voto_comentarios do |t|
      t.references :user, null: false, foreign_key: true
      t.references :comentario, null: false, foreign_key: true
      t.integer :valor, default: 1

      t.timestamps
    end

    add_index :voto_comentarios, [ :user_id, :comentario_id ], unique: true
  end
end
