namespace :questaos do
  desc "Atualiza a coluna classificacoes em lotes para otimizar queries com array/GIN"
  task backfill_classificacoes: :environment do
    # Configurável via variável de ambiente (ex: BATCH_SIZE=500 rails questaos:backfill_classificacoes)
    batch_size = ENV.fetch('BATCH_SIZE', 1000).to_i
    sleep_time = ENV.fetch('SLEEP_TIME', 0.1).to_f
    
    total = Questao.count
    processed = 0

    puts "Iniciando backfill de classificacoes para #{total} questões..."
    puts "Tamanho do lote: #{batch_size} | Intervalo entre lotes: #{sleep_time}s"

    # Utilizamos `in_batches` em vez de `find_each`.
    # O `in_batches` retorna um ActiveRecord::Relation (o lote inteiro), 
    # permitindo encadear o `update_all` e processar tudo direto no banco por lote (WHERE id IN (...)),
    # sem instanciar os objetos Ruby em memória e sem disparar callbacks.
    Questao.in_batches(of: batch_size).each do |batch|
      batch.update_all(<<-SQL.squish)
        classificacoes = array_remove(ARRAY[
          CASE WHEN disciplina_id IS NOT NULL THEN 'd_' || disciplina_id ELSE NULL END,
          CASE WHEN assunto_id IS NOT NULL THEN 'a_' || assunto_id ELSE NULL END,
          CASE WHEN topico_id IS NOT NULL THEN 't_' || topico_id ELSE NULL END
        ]::varchar[], NULL)
      SQL

      # O count aqui é rápido pois o lote já tem um tamanho máximo pré-definido.
      processed += batch.pluck(:id).size
      
      # Printa o progresso na mesma linha (útil para logs acompanháveis no terminal)
      print "\rProcessadas #{processed} de #{total} questões (#{(processed.to_f / total * 100).round(2)}%)"
      
      # Uma pequena pausa ajuda a evitar estourar o connection pool, IOPS ou travar réplicas 
      # em bancos de dados gerenciados (RDS, DigitalOcean Managed DB, etc.)
      sleep(sleep_time) if sleep_time > 0
    end

    puts "\nBackfill concluído com sucesso!"
  end
end
