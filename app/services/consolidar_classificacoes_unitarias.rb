# Assuntos e tópicos com só 1 questão (kikiapps#12): para cada um, procura o
# equivalente com mais de 1 questão (mesma disciplina para assuntos, mesmo
# assunto para tópicos) e, se aplicar, move a questão para ele.
#
# Por padrão só gera o relatório (dry-run). Ver lib/tasks/classificacoes.rake.
class ConsolidarClassificacoesUnitarias
  Resultado = Struct.new(:tipo, :origem_id, :origem_nome, :escopo_id, :destino_id, :destino_nome, :score, :questao_ids, :acao, keyword_init: true)

  attr_reader :min_score, :max_questoes, :aplicar, :log

  # max_questoes: considera "pequeno" quem tem até esse número de questões (padrão 1)
  def initialize(min_score: 0.9, max_questoes: 1, aplicar: false, log: $stdout)
    @min_score = min_score
    @max_questoes = max_questoes
    @aplicar = aplicar
    @log = log
  end

  def assuntos
    contagem = Questao.where.not(assunto_id: nil).group(:assunto_id).count
    pequenos = contagem.select { |_, n| n <= max_questoes }.keys
    grandes = contagem.select { |_, n| n > max_questoes }.keys.to_set
    log.puts "Assuntos com até #{max_questoes} questão(ões): #{pequenos.size}"

    candidatos_por_disciplina = Assunto.where(id: grandes.to_a).pluck(:id, :nome, :disciplina_id)
                                       .group_by(&:last)
                                       .transform_values { |rows| rows.map { |id, nome, _| [id, nome] } }

    Assunto.where(id: pequenos).find_each.map do |assunto|
      pool = candidatos_por_disciplina.fetch(assunto.disciplina_id, [])
      match = EquivalenciaClassificacao.melhor(assunto.nome, pool)
      questao_ids = Questao.where(assunto_id: assunto.id).pluck(:id)
      resultado = Resultado.new(
        tipo: 'assunto', origem_id: assunto.id, origem_nome: assunto.nome, escopo_id: assunto.disciplina_id,
        destino_id: match&.dig(:id), destino_nome: match&.dig(:nome), score: match&.dig(:score),
        questao_ids: questao_ids, acao: acao_para(match)
      )
      mover_assunto!(resultado) if aplicar && resultado.acao == 'mover'
      resultado
    end
  end

  def topicos
    contagem = Questao.where.not(topico_id: nil).group(:topico_id).count
    pequenos = contagem.select { |_, n| n <= max_questoes }.keys
    grandes = contagem.select { |_, n| n > max_questoes }.keys.to_set
    log.puts "Tópicos com até #{max_questoes} questão(ões): #{pequenos.size}"

    candidatos_por_assunto = Topico.where(id: grandes.to_a).where.not(assunto_id: nil)
                                   .pluck(:id, :nome, :assunto_id)
                                   .group_by(&:last)
                                   .transform_values { |rows| rows.map { |id, nome, _| [id, nome] } }

    Topico.where(id: pequenos).find_each.map do |topico|
      pool = candidatos_por_assunto.fetch(topico.assunto_id, [])
      match = EquivalenciaClassificacao.melhor(topico.nome, pool)
      questao_ids = Questao.where(topico_id: topico.id).pluck(:id)
      resultado = Resultado.new(
        tipo: 'topico', origem_id: topico.id, origem_nome: topico.nome, escopo_id: topico.assunto_id,
        destino_id: match&.dig(:id), destino_nome: match&.dig(:nome), score: match&.dig(:score),
        questao_ids: questao_ids, acao: acao_para(match)
      )
      mover_topico!(resultado) if aplicar && resultado.acao == 'mover'
      resultado
    end
  end

  private

  def acao_para(match)
    return 'sem_candidato' if match.nil?

    match[:score] >= min_score ? 'mover' : 'revisar'
  end

  # Move as questões para o assunto equivalente. O tópico (que pertence ao
  # assunto antigo) é trocado pelo tópico equivalente do novo assunto, ou
  # removido se não houver equivalente. classificacoes é recalculado no save.
  def mover_assunto!(resultado)
    topicos_destino = Topico.where(assunto_id: resultado.destino_id).pluck(:id, :nome)
    Questao.where(id: resultado.questao_ids).find_each do |questao|
      novo_topico_id = nil
      if questao.topico_id.present? && (topico = Topico.find_by(id: questao.topico_id))
        match = EquivalenciaClassificacao.melhor(topico.nome, topicos_destino)
        novo_topico_id = match[:id] if match && match[:score] >= min_score
      end
      questao.update!(assunto_id: resultado.destino_id, topico_id: novo_topico_id)
    end
  end

  def mover_topico!(resultado)
    Questao.where(id: resultado.questao_ids).find_each do |questao|
      questao.update!(topico_id: resultado.destino_id)
    end
  end
end
