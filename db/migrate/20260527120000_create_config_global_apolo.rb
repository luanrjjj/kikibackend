class CreateConfigGlobalApolo < ActiveRecord::Migration[8.0]
  def change
    create_table :config_global_apolo do |t|
      t.string :nome_da_variavel, null: false
      t.string :valor_da_variavel
      t.timestamps
    end
    add_index :config_global_apolo, :nome_da_variavel, unique: true
  end
end
