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
  # Texto candidato a ser verificado pelo admin (ver migração AddTextToVerifyToQuestaos)
  belongs_to :texto_para_verificar, class_name: 'Texto', foreign_key: :text_to_verify, optional: true

  validates :enunciado, presence: true
  validates :ano, presence: true
  validates :discursiva, inclusion: { in: [true, false] }

  before_save :set_classificacoes
  after_commit :expirar_cache_das_provas, on: %i[update destroy]

  def disciplina_nome
    disciplina&.nome
  end

  def assunto_nome
    assunto&.nome
  end

  def topico_nome
    topico&.nome
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
      topico_nome: topico_nome,
      prova_nome: prova_nome,
      banca_nome: banca_nome,
      orgao_nome: orgao_nome,
      texto_id: texto_id,
      texto: texto&.texto,
      texto_imagem: texto&.imagem_texto,
      text_to_verify: text_to_verify,
      text_to_verify_texto: texto_para_verificar&.texto,
      classificacao_origem: classificacao_origem,
      classificao_origem: classificacao_origem
    })
  end

  private

  # GET /provas/:id/questaos fica em cache; sem isso a edição (ex.: vincular
  # texto) só aparecia na tela da prova depois que o cache expirasse.
  def expirar_cache_das_provas
    Prova.expirar_cache_questaos(ProvaQuestao.where(questao_id: self[:id]).pluck(:prova_id))
  end

  def set_classificacoes
    self.classificacoes = [
      ("d_#{disciplina_id}" if disciplina_id.present?),
      ("a_#{assunto_id}" if assunto_id.present?),
      ("t_#{topico_id}" if topico_id.present?)
    ].compact
  end
end