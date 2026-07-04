class CreateAnotacaos < ActiveRecord::Migration[8.0]
  def change
    create_table :anotacaos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :questao, null: false, foreign_key: true
      t.text :texto

      t.timestamps
    end
  end
end
