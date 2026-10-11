class Resolucao < ApplicationRecord
  self.primary_key = [:id, :created_at]

  belongs_to :user
  belongs_to :questao
  belongs_to :caderno, optional: true

  validates :resposta, presence: true

  # Resoluções feitas de fato pelo usuário (exclui cópias trazidas para um
  # caderno por "Atualizar resoluções"). Use em estatísticas globais.
  scope :originais, -> { where(importada_de_id: nil) }
  scope :importadas, -> { where.not(importada_de_id: nil) }

  def importada?
    importada_de_id.present?
  end
end
