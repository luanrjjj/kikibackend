class AddTextoToComentarios < ActiveRecord::Migration[8.0]
  def change
    add_column :comentarios, :texto, :text
  end
end
