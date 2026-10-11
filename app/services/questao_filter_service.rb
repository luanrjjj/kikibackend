# Applies the question-bank filters (banca, órgão, ano, escolaridade,
# disciplina/assunto/tópico, anuladas/desatualizadas) to a Questao scope.
#
# Shared by QuestaosController (filters page, /questaos/ids, /questaos/count)
# and by Caderno#verificar_atualizacoes, so a notebook is always refreshed with
# exactly the same rule that was used to build it.
class QuestaoFilterService
  FILTER_KEYS = %w[bancas orgaos ano escolaridade disciplinas assuntos topicos].freeze

  # @param scope [ActiveRecord::Relation] base relation (usually Questao.all)
  # @param filters [Hash] keys: bancas, orgaos, ano, escolaridade, disciplinas,
  #   assuntos, topicos, remover_anuladas, remover_desatualizadas
  # @return [ActiveRecord::Relation]
  def self.apply(scope, filters)
    f = (filters || {}).to_h.with_indifferent_access
    questaos = scope

    bancas = f[:bancas]
    orgaos = f[:orgaos]
    if bancas.present? || orgaos.present?
      questaos = questaos.joins(:concurso)
      questaos = questaos.where(concursos: { banca_id: bancas }) if bancas.present?
      questaos = questaos.where(concursos: { orgao_id: orgaos }) if orgaos.present?
    end

    ano = f[:ano]
    if ano.present?
      if ano.is_a?(Array)
        questaos = questaos.where(ano: ano)
      elsif ano.to_s.include?('-')
        start_year, end_year = ano.to_s.split('-').map(&:to_i)
        questaos = questaos.where(ano: start_year..end_year)
      else
        questaos = questaos.where(ano: ano)
      end
    end

    if f[:escolaridade].present?
      # EXISTS is usually faster than IN (SELECT ...) in PostgreSQL
      questaos = questaos.where(
        "EXISTS (SELECT 1 FROM prova_questaos pq JOIN provas p ON pq.prova_id = p.id WHERE pq.questao_id = questaos.id AND p.escolaridade IN (?))",
        Array(f[:escolaridade])
      )
    end

    if f[:disciplinas].present? || f[:assuntos].present? || f[:topicos].present?
      classificacoes = []
      classificacoes += Array(f[:disciplinas]).map { |id| "d_#{id}" } if f[:disciplinas].present?
      classificacoes += Array(f[:assuntos]).map { |id| "a_#{id}" } if f[:assuntos].present?
      classificacoes += Array(f[:topicos]).map { |id| "t_#{id}" } if f[:topicos].present?

      # PostgreSQL array overlap (&&): matches ANY of the given classifications
      questaos = questaos.where("classificacoes && ?", "{#{classificacoes.join(',')}}")
    end

    questaos = questaos.where(anulada: nil) if truthy?(f[:remover_anuladas])
    questaos = questaos.where(desatualizada: nil) if truthy?(f[:remover_desatualizadas])

    questaos
  end

  # True when at least one real criterion is present (avoids matching the whole bank).
  def self.any_criteria?(filters)
    f = (filters || {}).to_h.with_indifferent_access
    FILTER_KEYS.any? { |k| f[k].present? }
  end

  def self.truthy?(value)
    value == true || value.to_s == 'true'
  end
  private_class_method :truthy?
end
