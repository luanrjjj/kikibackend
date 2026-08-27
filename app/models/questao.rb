class Questao < ApplicationRecord
  self.primary_key = [:id, :created_at]

  has_many :prova_questaos, dependent: :destroy
  has_many :provas, through: :prova_questaos
  has_many :comentarios, dependent: :destroy
  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :anotacaos, class_name: 'Anotacao', dependent: :destroy

  belongs_to :concurso, optional: true
  belongs_to :assunto, optional: true
  belongs_to :disciplina, optional: true
  belongs_to :topico, optional: true

  belongs_to :texto, optional: true

  validates :enunciado, presence: true
  validates :ano, presence: true
  validates :discursiva, inclusion: { in: [true, false] }

  before_save :set_classificacoes

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

  def classificao_origem
    classificacao_origem
  end

  def classificao_origem=(val)
    self.classificacao_origem = val
  end

  def as_json(options = {})
    super(options).merge({
      disciplina_nome: disciplina_nome,
      assunto_nome: assunto_nome,
      prova_nome: prova_nome,
      banca_nome: banca_nome,
      orgao_nome: orgao_nome,
      texto_id: texto_id,
      texto: texto&.texto,
      texto_imagem: texto&.imagem_texto,
      classificacao_origem: classificacao_origem,
      classificao_origem: classificacao_origem
    })
  end

  private

  def set_classificacoes
    self.classificacoes = [
      ("d_#{disciplina_id}" if disciplina_id.present?),
      ("a_#{assunto_id}" if assunto_id.present?),
      ("t_#{topico_id}" if topico_id.present?)
    ].compact
  end
end