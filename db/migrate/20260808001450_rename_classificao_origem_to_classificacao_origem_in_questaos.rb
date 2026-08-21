class RenameClassificaoOrigemToClassificacaoOrigemInQuestaos < ActiveRecord::Migration[8.0]
  def change
    rename_column :questaos, :classificao_origem, :classificacao_origem
  end
end
