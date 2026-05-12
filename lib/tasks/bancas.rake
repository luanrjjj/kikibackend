namespace :bancas do
  desc "Atualiza os contadores de questões por banca via Sidekiq Job"
  task refresh_counts: :environment do
    RefreshBancaCountsJob.perform_async
  end
end

