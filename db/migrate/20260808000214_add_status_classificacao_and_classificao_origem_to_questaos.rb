class AddStatusClassificacaoAndClassificaoOrigemToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :status_classificacao, :string
    add_column :questaos, :classificao_origem, :string
  end
end
