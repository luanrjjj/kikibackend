class Concurso < ApplicationRecord
  belongs_to :banca
  belongs_to :orgao
  has_many :provas, dependent: :destroy
  has_many :questaos, dependent: :destroy
  has_many :textos, dependent: :destroy
  has_many :comentarios, dependent: :destroy

  ESTAGIOS = [
    'previsto',
    'autorizado',
    'aberto',
    'inscrições abertas',
    'inscrições encerradas',
    'encerrado'
  ].freeze

  validates :nome, presence: true, uniqueness: { scope: [:inscricoes_ate, :banca_id, :orgao_id], message: "já existe um concurso com esses mesmos dados" }
  validates :estagio, inclusion: { in: ESTAGIOS }, allow_nil: true
end
