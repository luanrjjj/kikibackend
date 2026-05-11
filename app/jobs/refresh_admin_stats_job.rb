class RefreshAdminStatsJob
  include Sidekiq::Job
  queue_as :default

  def perform
    Rails.logger.info "Iniciando atualização de estatísticas do Admin..."

    # 1. Estatísticas de Questões
    questao_stats = Questao.select(
      "COUNT(*) as total",
      "COUNT(*) FILTER (WHERE correta IS NOT NULL AND correta != '') as with_correct",
      "COUNT(*) FILTER (WHERE disciplina_id IS NOT NULL) as with_disciplina",
      "COUNT(*) FILTER (WHERE assunto_id IS NOT NULL) as with_assunto",
      "COUNT(*) FILTER (WHERE disciplina_id IS NOT NULL AND assunto_id IS NOT NULL) as with_disciplina_assunto",
      "COUNT(*) FILTER (WHERE validado_admin IS NOT NULL) as validated"
    ).take

    questoes_by_year = Questao.where.not(ano: nil).group(:ano).count.sort.to_h

    stats_data = {
      total_count: questao_stats.total || 0,
      with_correct_answer_count: questao_stats.with_correct || 0,
      with_disciplina_count: questao_stats.with_disciplina || 0,
      with_assunto_count: questao_stats.with_assunto || 0,
      with_disciplina_assunto_count: questao_stats.with_disciplina_assunto || 0,
      validated_count: questao_stats.validated || 0,
      by_year: questoes_by_year,
      updated_at: Time.current
    }

    Rails.cache.write("admin/stats/questaos/global", stats_data)

    # 2. Estatísticas de Provas
    provas_total = Prova.count
    provas_by_year = Prova.where.not(ano: nil).group(:ano).count.sort.to_h

    provas_stats = {
      total_count: provas_total,
      by_year: provas_by_year,
      updated_at: Time.current
    }

    Rails.cache.write("admin/stats/provas/global", provas_stats)

    # 3. Estatísticas de Concursos
    concursos_total = Concurso.count
    concursos_by_year = Concurso.joins(:provas)
                                .group('provas.ano')
                                .distinct
                                .count('concursos.id')
                                .sort.to_h

    concursos_stats = {
      total_count: concursos_total,
      by_year: concursos_by_year,
      updated_at: Time.current
    }

    Rails.cache.write("admin/stats/concursos/global", concursos_stats)

    Rails.logger.info "Atualização de estatísticas do Admin concluída."
  end
end
