namespace :bancas do
  desc "Atualiza os contadores de questões por banca via Sidekiq Job"
  task refresh_counts: :environment do
    RefreshBancaCountsJob.new.perform
  end
end

