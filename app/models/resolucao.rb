class Resolucao < ApplicationRecord
  self.primary_key = [:id, :created_at]

  belongs_to :user
  belongs_to :questao
  belongs_to :caderno, optional: true

  validates :resposta, presence: true

  after_commit :sync_to_clickhouse, on: [:create, :update]

  private

  def sync_to_clickhouse
    ClickhouseSyncJob.perform_async(self.id)
  end
end
