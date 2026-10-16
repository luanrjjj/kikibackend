class Export < ApplicationRecord
  STATUS = %w[pendente processando concluido erro].freeze

  belongs_to :user
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true

  validates :questoes_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUS }

  # Exportações que contam no limite semanal do plano (falhas não contam)
  scope :validas, -> { where.not(status: 'erro') }

  def concluido?
    status == 'concluido'
  end

  def as_status_json
    {
      id: id,
      status: status,
      progresso: progresso.to_i,
      titulo: titulo,
      questoes_count: questoes_count,
      erro: erro,
      created_at: created_at,
      concluido_em: concluido_em
    }
  end
end
