require "clickhouse"

class ClickhouseSyncService
  def self.client
    @client ||= begin
      ::Clickhouse.establish_connection(
        host:     ENV.fetch("CLICKHOUSE_HOST", "localhost"),
        port:     ENV.fetch("CLICKHOUSE_PORT", "8123"),
        username: ENV.fetch("CLICKHOUSE_USER", "default"),
        password: ENV.fetch("CLICKHOUSE_PASSWORD", ""),
        database: ENV.fetch("CLICKHOUSE_DB", "default")
      )
      ::Clickhouse.connection
    end
  end

  def self.sync_questao(questao_id)
    questao = Questao.find(questao_id)
    concurso = questao.concurso
    prova = questao.provas.first
    orgao = concurso&.orgao
    banca = concurso&.banca
    
    data = {
      id: questao.read_attribute(:id),
      discursiva: questao.discursiva ? 1 : 0,
      anulada: questao.anulada,
      desatualizada: questao.desatualizada,
      ano: questao.ano,
      alternativas: questao.alternativas.to_json,
      correta: questao.correta,
      enunciado: questao.enunciado,
      sistema_ref_id: questao.sistema_ref_id,
      texto_id: questao.texto_id,
      created_at: questao.created_at.strftime("%Y-%m-%d %H:%M:%S"),
      updated_at: questao.updated_at.strftime("%Y-%m-%d %H:%M:%S"),
      validado_admin: questao.validado_admin&.strftime("%Y-%m-%d %H:%M:%S"),
      disciplina_ref: questao.disciplina_ref,
      assunto_ref: questao.assunto_ref.is_a?(Array) ? "[#{questao.assunto_ref.map { |s| "'#{s.to_s.gsub("'", "''")}'" }.join(",")}]" : "[]",

      # Concurso
      concurso_id: concurso&.id,
      concurso_nome: concurso&.nome,

      # Prova
      prova_id: prova&.id,
      prova_nome: prova&.nome,
      prova_ano: prova&.ano,

      # Disciplina
      disciplina_id: questao.disciplina_id,
      disciplina_nome: questao.disciplina&.nome,

      # Assunto
      assunto_id: questao.assunto_id,
      assunto_nome: questao.assunto&.nome,

      # Orgao
      orgao_id: orgao&.id,
      orgao_nome: orgao&.nome,
      orgao_sigla: orgao&.sigla,

      # Banca
      banca_id: banca&.id,
      banca_nome: banca&.nome,
      banca_sigla: banca&.sigla
    }

    client.insert_rows("questaos", rows: [ data ])
  rescue StandardError => e
    Rails.logger.error "ClickhouseSyncService sync_questao Error: #{e.message}"
    raise e
  end

  def self.sync_resolution(resolucao_id)
    resolucao = Resolucao.find(resolucao_id)
    questao = resolucao.questao
    concurso = questao.concurso
    orgao = concurso&.orgao
    prova = questao.provas.first
    disciplina = questao.disciplina
    assunto = questao.assunto

    data = {
      id: resolucao.read_attribute(:id),
      user_id: resolucao.user_id,
      questao_id: resolucao.questao_id,
      caderno_id: resolucao.caderno_id,
      resposta: resolucao.resposta.to_s,
      correta: resolucao.correta ? 1 : 0,
      created_at: resolucao.created_at.strftime("%Y-%m-%d %H:%M:%S"),

      # Prova
      prova_id: prova&.id || 0,
      prova_nome: prova&.nome || "N/A",
      prova_ano: prova&.ano || 0,

      # Concurso
      concurso_id: concurso&.id || 0,
      concurso_nome: concurso&.nome || "N/A",

      # Orgao
      orgao_id: orgao&.id || 0,
      orgao_nome: orgao&.nome || "N/A",
      orgao_sigla: orgao&.sigla || "N/A",
      orgao_esfera: orgao&.esfera || "N/A",

      # Disciplina
      disciplina_id: disciplina&.id || 0,
      disciplina_nome: disciplina&.nome || "N/A",

      # Assunto
      assunto_id: assunto&.id || 0,
      assunto_nome: assunto&.nome || "N/A"
    }

    client.insert_rows("resolucaos", rows: [ data ])
  rescue StandardError => e
    Rails.logger.error "ClickhouseSyncService sync_resolution Error: #{e.message}"
    raise e
  end
end
