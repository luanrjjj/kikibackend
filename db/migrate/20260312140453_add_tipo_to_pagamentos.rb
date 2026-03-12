class AddTipoToPagamentos < ActiveRecord::Migration[8.0]
  def change
    add_column :pagamentos, :tipo, :string
  end
end
