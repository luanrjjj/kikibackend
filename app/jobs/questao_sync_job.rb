class QuestaoSyncJob
  include Sidekiq::Job

  def perform(questao_id)
    ClickhouseSyncService.sync_questao(questao_id)
  end
end
