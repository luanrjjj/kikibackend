require 'clickhouse'

class ClickhouseSyncService
  def self.client
    @client ||= ::Clickhouse.connection(
      host:     ENV.fetch('CLICKHOUSE_HOST', 'localhost'),
      port:     ENV.fetch('CLICKHOUSE_PORT', '8123'),
      username: ENV.fetch('CLICKHOUSE_USER', 'default'),
      password: ENV.fetch('CLICKHOUSE_PASSWORD', ''),
      database: ENV.fetch('CLICKHOUSE_DB', 'default')
    )
  end

  def self.sync_resolution(resolucao_id)
    resolucao = Resolucao.find(resolucao_id)
    questao = resolucao.questao
    concurso = questao.concurso
    orgao = concurso&.orgao
    prova = questao.provas.first # Assumindo que pegamos a primeira prova associada
    disciplina = questao.disciplina
    assunto = questao.assunto

    data = {
      id: resolucao.id,
      user_id: resolucao.user_id,
      questao_id: resolucao.questao_id,
      caderno_id: resolucao.caderno_id,
      resposta: resolucao.resposta.to_s,
      correta: resolucao.correta ? 1 : 0,
      created_at: resolucao.created_at.strftime('%Y-%m-%d %H:%M:%S'),
      
      # Prova
      prova_id: prova&.id || 0,
      prova_nome: prova&.nome || 'N/A',
      prova_ano: prova&.ano || 0,

      # Concurso
      concurso_id: concurso&.id || 0,
      concurso_nome: concurso&.nome || 'N/A',

      # Orgao
      orgao_id: orgao&.id || 0,
      orgao_nome: orgao&.nome || 'N/A',
      orgao_sigla: orgao&.sigla || 'N/A',
      orgao_esfera: orgao&.esfera || 'N/A',

      # Disciplina
      disciplina_id: disciplina&.id || 0,
      disciplina_nome: disciplina&.nome || 'N/A',

      # Assunto
      assunto_id: assunto&.id || 0,
      assunto_nome: assunto&.nome || 'N/A'
    }

    client.insert('resolucaos', [data])
  rescue StandardError => e
    Rails.logger.error "ClickhouseSyncService Error: #{e.message}"
    raise e
  end
end
