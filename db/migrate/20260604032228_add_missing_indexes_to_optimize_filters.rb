class AddMissingIndexesToOptimizeFilters < ActiveRecord::Migration[8.0]
  def change
    # Index for filtering questao by multiple criteria
    unless index_exists?(:questaos, [:disciplina_id, :assunto_id, :topico_id, :ano, :anulada, :desatualizada], name: 'idx_questaos_filters_composite')
      add_index :questaos, [:disciplina_id, :assunto_id, :topico_id, :ano, :anulada, :desatualizada], name: 'idx_questaos_filters_composite'
    end
    
    # Index for joining with concursos and counting
    unless index_exists?(:questaos, [:concurso_id, :id], name: 'idx_questaos_concurso_id_id')
      add_index :questaos, [:concurso_id, :id], name: 'idx_questaos_concurso_id_id'
    end
    
    # Index for faster EXISTS checks in prova_questaos
    unless index_exists?(:prova_questaos, [:questao_id, :prova_id], name: 'idx_prova_questaos_composite')
      add_index :prova_questaos, [:questao_id, :prova_id], name: 'idx_prova_questaos_composite'
    end
    
    # Index for faster escolaridade filtering in provas
    unless index_exists?(:provas, [:escolaridade, :id], name: 'idx_provas_escolaridade_id')
      add_index :provas, [:escolaridade, :id], name: 'idx_provas_escolaridade_id'
    end
    
    # Index for faster banca/orgao filtering in concursos
    unless index_exists?(:concursos, [:banca_id, :orgao_id, :id], name: 'idx_concursos_banca_orgao_id')
      add_index :concursos, [:banca_id, :orgao_id, :id], name: 'idx_concursos_banca_orgao_id'
    end
  end
end
