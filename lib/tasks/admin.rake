namespace :admin do
  desc "Atualiza as estatísticas globais do dashboard admin via Sidekiq"
  task refresh_stats: :environment do
    puts "Enfileirando RefreshAdminStatsJob..."
    RefreshAdminStatsJob.perform_async
    puts "Job enfileirado com sucesso!"
  end
end
