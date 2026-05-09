namespace :clickhouse do
  desc "Migra todas as questões do PostgreSQL para o ClickHouse"
  task migrate_questaos: :environment do
    batch_size = 5000
    table_name = "questaos"

    puts "Iniciando migração de questões para o ClickHouse..."

    # Garantir que a tabela existe no ClickHouse
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
        concurso_id Nullable(Int64),
        assunto_id Nullable(Int64),
        disciplina_id Nullable(Int64),
        texto_id Nullable(Int64),
        created_at DateTime,
        updated_at DateTime,
        disciplina_ref Nullable(String),
        assunto_ref Array(String)
      ) ENGINE = MergeTree()
      ORDER BY id;
    SQL

    total_questaos = Questao.count
    processed = 0

    Questao.find_in_batches(batch_size: batch_size) do |batch|
      data = batch.map do |q|
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
          concurso_id: q.concurso_id,
          assunto_id: q.assunto_id,
          disciplina_id: q.disciplina_id,
          texto_id: q.texto_id,
          created_at: q.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          updated_at: q.updated_at.strftime("%Y-%m-%d %H:%M:%S"),
          disciplina_ref: q.disciplina_ref,
          assunto_ref: q.assunto_ref.is_a?(Array) ? "[#{q.assunto_ref.map { |s| "'#{s.gsub("'", "\\'")}'" }.join(",")}]" : "[]"
        }
      end

      ClickhouseSyncService.client.insert_rows(table_name, rows: data)
      processed += batch.size
      progress = (processed.to_f / total_questaos * 100).round(2)
      puts "Processadas: #{processed} / #{total_questaos} (#{progress}%)"
    end

    puts "Migração concluída com sucesso!"
  end
end
