class AddImagemTextoToTextos < ActiveRecord::Migration[8.0]
  def change
    add_column :textos, :imagem_texto, :string
  end
end
