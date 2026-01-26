class AreaDeFormacao < ActiveRecord::Migration[8.0]
  def change
    create_table :area_de_formacaos do |t|
      t.string :nome, null: false
      t.timestamps
    end
  end
end
