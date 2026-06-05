class AddVariaveisToPlanos < ActiveRecord::Migration[8.0]
  def change
    add_column :planos, :variaveis, :string, array: true, default: []
  end
end
