class RefreshBancaCountsJob
  include Sidekiq::Job
  sidekiq_options queue: :default

  def perform
    Rails.logger.info "Iniciando atualização de contadores de bancas..."
    
    # 1. Reset all counts to 0 first (in case some bancas no longer have questions)
    Banca.update_all(questaos_count: 0, com_gabarito_count: 0)

    # 2. Busca os totais em uma única query otimizada
    stats = Questao.joins(:concurso)
                   .group('concursos.banca_id')
                   .select('concursos.banca_id, 
                           count(questaos.id) as total,
                           count(CASE WHEN correta IS NOT NULL AND correta != \'\' THEN 1 END) as com_gabarito')

    stats.each do |stat|
      Banca.where(id: stat.banca_id).update_all(
        questaos_count: stat.total,
        com_gabarito_count: stat.com_gabarito
      )
    end

    # 3. Update cache version to invalidate old results
    ConfigGlobalApolo.set('bancas_questoes_count_version', Time.current.to_i.to_s)

    Rails.logger.info "Atualização de contadores de bancas concluída."
  end
end
