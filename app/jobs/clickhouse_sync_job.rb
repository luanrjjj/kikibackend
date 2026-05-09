class ClickhouseSyncJob
  include Sidekiq::Job

  def perform(resolucao_id)
    ClickhouseSyncService.sync_resolution(resolucao_id)
  end
end
