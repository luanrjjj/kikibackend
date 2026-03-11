class AddAddressDetailsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :cep, :string
    add_column :users, :telefone, :string
    add_column :users, :endereco, :string
    add_column :users, :endereco_numero, :string
    add_column :users, :cidade, :string
    add_column :users, :estado, :string
  end
end
