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

  def disciplina_nome
    disciplina&.nome
  end

  def assunto_nome
    assunto&.nome
  end

  def prova_nome
    provas.first&.nome
  end

  def banca_nome
    concurso&.banca&.nome
  end

  def orgao_nome
    concurso&.orgao&.nome
  end

  def as_json(options = {})
    super(options).merge({
      disciplina_nome: disciplina_nome,
      assunto_nome: assunto_nome,
      prova_nome: prova_nome,
      banca_nome: banca_nome,
      orgao_nome: orgao_nome
    })
  end
end