class Questao < ApplicationRecord
  self.primary_key = [:id, :created_at]

  has_many :prova_questaos, dependent: :destroy
  has_many :provas, through: :prova_questaos
  has_many :comentarios, dependent: :destroy
  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy

  belongs_to :concurso, optional: true
  belongs_to :assunto, optional: true
  belongs_to :disciplina, optional: true

  belongs_to :texto, optional: true

  validates :enunciado, presence: true
  validates :ano, presence: true
  validates :discursiva, inclusion: { in: [true, false] }

  after_commit :sync_to_clickhouse, on: [:create, :update]

  private

  def sync_to_clickhouse
    QuestaoSyncJob.perform_async(self.id)
  end
end