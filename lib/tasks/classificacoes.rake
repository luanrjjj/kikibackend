# Consolidação de assuntos/tópicos com só 1 questão (kikiapps#12).
#
#   bin/rails classificacoes:unitarios                 # relatório (não altera nada)
#   APLICAR=1 bin/rails classificacoes:unitarios       # move as questões (score >= MIN_SCORE)
#
# Variáveis:
#   TIPO=assuntos|topicos|todos (padrão todos)
#   MIN_SCORE=0.9   similaridade mínima de nome para mover (0..1)
#   MAX_QUESTOES=1  considera "pequeno" quem tem até N questões
#
# O relatório (JSON) vai para tmp/consolidacao_unitarios_<data>.json com, para
# cada item: origem, melhor equivalente, score, questões e ação
# (mover | revisar | sem_candidato). Itens "revisar" ficam para análise manual.
# Assuntos/tópicos esvaziados não são apagados.
namespace :classificacoes do
  desc 'Assuntos e tópicos com só 1 questão: encontra o equivalente com mais questões (APLICAR=1 move)'
  task unitarios: :environment do
    aplicar = ENV['APLICAR'] == '1'
    tipo = ENV.fetch('TIPO', 'todos')
    runner = ConsolidarClassificacoesUnitarias.new(
      min_score: ENV.fetch('MIN_SCORE', '0.9').to_f,
      max_questoes: ENV.fetch('MAX_QUESTOES', '1').to_i,
      aplicar: aplicar
    )

    puts aplicar ? '>> Modo APLICAR: as questões serão movidas.' : '>> Simulação: nada será alterado (use APLICAR=1 para mover).'

    resultados = []
    resultados += runner.assuntos if %w[assuntos todos].include?(tipo)
    resultados += runner.topicos if %w[topicos todos].include?(tipo)

    resumo = resultados.group_by { |r| [r.tipo, r.acao] }.transform_values(&:size)
    resumo.sort.each { |(t, acao), n| puts format('  %-8s %-14s %6d', t, acao, n) }

    resultados.select { |r| r.acao == 'mover' }.first(30).each do |r|
      puts format('  [%s] #%d "%s" -> #%d "%s" (%.2f, %d questão(ões))', r.tipo, r.origem_id, r.origem_nome, r.destino_id, r.destino_nome, r.score, r.questao_ids.size)
    end

    caminho = Rails.root.join('tmp', "consolidacao_unitarios_#{Time.current.strftime('%Y%m%d%H%M%S')}.json")
    File.write(caminho, JSON.pretty_generate(
      aplicado: aplicar,
      min_score: runner.min_score,
      max_questoes: runner.max_questoes,
      resumo: resumo.map { |(t, acao), n| { tipo: t, acao: acao, total: n } },
      itens: resultados.map(&:to_h)
    ))
    puts "Relatório: #{caminho}"
  end
end
