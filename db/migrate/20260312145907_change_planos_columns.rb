class ChangePlanosColumns < ActiveRecord::Migration[8.0]
  def change
    rename_column :planos, :valor, :valor_mensal
    rename_column :planos, :valor_promocional, :valor_promocional_mensal
    add_column :planos, :valor_anual, :decimal, precision: 8, scale: 2
    add_column :planos, :valor_promocional_anual, :decimal, precision: 8, scale: 2
  end
end
