class AsaasUserInfo < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :asaas_customer_id, :string
    add_column :users, :cpf, :string
    add_index :users, :asaas_customer_id, unique: true
  end
end
