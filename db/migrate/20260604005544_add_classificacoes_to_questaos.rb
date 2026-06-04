class AddClassificacoesToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :classificacoes, :string, array: true, default: []
    add_index :questaos, :classificacoes, using: :gin, name: 'idx_questaos_classificacoes_gin'
  end
end
