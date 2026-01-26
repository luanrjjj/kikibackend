class AreaDeAtuacao < ActiveRecord::Migration[8.0]
  def change
    create_table :area_de_atuacaos do |t|
      t.string :nome, null: false
      t.timestamps
    end
  end
end
