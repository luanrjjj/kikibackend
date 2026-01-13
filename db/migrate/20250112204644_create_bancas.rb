class CreateBancas < ActiveRecord::Migration[8.0]
  def change
    create_table :bancas do |t|
      t.string :name, null: false
      t.string :logo
      t.string :sigla, null: false
      t.timestamps
    end
  end
end
