class RefreshBancaCountsJob
  include Sidekiq::Job
  queue_as :default

  def perform
    Rails.logger.info "Iniciando atualização de contadores de bancas..."
    
    # Busca os totais em uma única query otimizada
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

    Rails.logger.info "Atualização de contadores de bancas concluída."
  end
end
