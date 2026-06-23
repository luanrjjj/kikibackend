class Concurso < ApplicationRecord
  belongs_to :banca
  belongs_to :orgao
  has_many :provas, dependent: :destroy
  has_many :questaos, dependent: :destroy
  has_many :textos, dependent: :destroy
  has_many :comentarios, dependent: :destroy
  has_many :edital_verts, class_name: "EditalVert", foreign_key: "concurso_id", dependent: :nullify
  has_many :guias, dependent: :destroy

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

  def similar_concursos(limit = 5)
    return Concurso.none unless orgao

    Concurso.joins(:orgao)
            .where.not(id: id)
            .order(
              Arel.sql(
                ActiveRecord::Base.sanitize_sql_array([
                  "CASE WHEN orgao_id = ? THEN 0 ELSE 1 END, CASE WHEN banca_id = ? THEN 0 ELSE 1 END, CASE WHEN orgaos.esfera = ? THEN 0 ELSE 1 END, COALESCE(inscricoes_ate, '1970-01-01') DESC, concursos.created_at DESC",
                  orgao_id,
                  banca_id,
                  orgao.esfera
                ])
              )
            )
            .limit(limit)
  end
end
