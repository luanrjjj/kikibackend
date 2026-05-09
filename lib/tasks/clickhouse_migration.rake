namespace :clickhouse do
  desc "Migra todas as questões do PostgreSQL para o ClickHouse com dados desnormalizados"
  task migrate_questaos: :environment do
    batch_size = 1000
    table_name = "questaos"

    puts "Iniciando migração desnormalizada de questões para o ClickHouse..."

    # Garantir que a tabela existe no ClickHouse com todos os campos desnormalizados
    ClickhouseSyncService.client.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS #{table_name} (
        id Int64,
        discursiva UInt8,
        anulada Nullable(Date),
        desatualizada Nullable(Date),
        ano Int32,
        alternativas String,
        correta Nullable(String),
        enunciado String,
        sistema_ref_id Nullable(String),
        texto_id Nullable(Int64),
        created_at DateTime,
        updated_at DateTime,
        validado_admin Nullable(DateTime),
        disciplina_ref Nullable(String),
        assunto_ref Array(String),

        # Concurso
        concurso_id Nullable(Int64),
        concurso_nome Nullable(String),

        # Prova
        prova_id Nullable(Int64),
        prova_nome Nullable(String),
        prova_ano Nullable(Int32),

        # Disciplina
        disciplina_id Nullable(Int64),
        disciplina_nome Nullable(String),

        # Assunto
        assunto_id Nullable(Int64),
        assunto_nome Nullable(String),

        # Orgao
        orgao_id Nullable(Int64),
        orgao_nome Nullable(String),
        orgao_sigla Nullable(String),

        # Banca
        banca_id Nullable(Int64),
        banca_nome Nullable(String),
        banca_sigla Nullable(String)
      ) ENGINE = MergeTree()
      ORDER BY id;
    SQL

    total_questaos = Questao.count
    processed = 0

    Questao.find_in_batches(batch_size: batch_size) do |batch|
      # Preload associations for performance
      ActiveRecord::Associations::Preloader.new(records: batch, associations: [
        :provas, 
        :disciplina, 
        :assunto, 
        { concurso: [:orgao, :banca] }
      ]).call

      data = batch.map do |q|
        concurso = q.concurso
        prova = q.provas.first
        orgao = concurso&.orgao
        banca = concurso&.banca
        
        {
          id: q.read_attribute(:id),
          discursiva: q.discursiva ? 1 : 0,
          anulada: q.anulada,
          desatualizada: q.desatualizada,
          ano: q.ano,
          alternativas: q.alternativas.to_json,
          correta: q.correta,
          enunciado: q.enunciado,
          sistema_ref_id: q.sistema_ref_id,
          texto_id: q.texto_id,
          created_at: q.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          updated_at: q.updated_at.strftime("%Y-%m-%d %H:%M:%S"),
          validado_admin: q.validado_admin&.strftime("%Y-%m-%d %H:%M:%S"),
          disciplina_ref: q.disciplina_ref,
          assunto_ref: q.assunto_ref.is_a?(Array) ? "[#{q.assunto_ref.map { |s| "'#{s.to_s.gsub("'", "''")}'" }.join(",")}]" : "[]",

          # Concurso
          concurso_id: concurso&.id,
          concurso_nome: concurso&.nome,

          # Prova
          prova_id: prova&.id,
          prova_nome: prova&.nome,
          prova_ano: prova&.ano,

          # Disciplina
          disciplina_id: q.disciplina_id,
          disciplina_nome: q.disciplina&.nome,

          # Assunto
          assunto_id: q.assunto_id,
          assunto_nome: q.assunto&.nome,

          # Orgao
          orgao_id: orgao&.id,
          orgao_nome: orgao&.nome,
          orgao_sigla: orgao&.sigla,

          # Banca
          banca_id: banca&.id,
          banca_nome: banca&.nome,
          banca_sigla: banca&.sigla
        }
      end

      ClickhouseSyncService.client.insert_rows(table_name, rows: data)
      processed += batch.size
      progress = (processed.to_f / total_questaos * 100).round(2)
      puts "Processadas: #{processed} / #{total_questaos} (#{progress}%)"
    end

    puts "Migração desnormalizada concluída com sucesso!"
  end
end
