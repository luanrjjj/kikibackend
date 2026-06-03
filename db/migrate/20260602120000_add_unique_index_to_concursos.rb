class AddUniqueIndexToConcursos < ActiveRecord::Migration[8.0]
  def change
    add_index :concursos, [:nome, :inscricoes_ate, :banca_id, :orgao_id], unique: true, name: 'idx_concursos_uniqueness'
  end
end
