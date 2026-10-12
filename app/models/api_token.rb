# Token pessoal de acesso, gerado pelo usuário no perfil para conectar
# a própria IA (Claude, Cursor etc.) ao Apolo via MCP ou à rota de questões
# para Anki.
#
# O token só é mostrado na criação. No banco fica apenas o SHA-256 dele,
# então um vazamento do banco não expõe tokens utilizáveis.
class ApiToken < ApplicationRecord
  PREFIXO = 'apl_'.freeze
  MAX_ATIVOS_POR_USUARIO = 10
  # Evita um UPDATE por requisição: last_used_at só é gravado se a última
  # marcação tiver mais que isso.
  INTERVALO_REGISTRO_USO = 5.minutes

  belongs_to :user

  validates :nome, presence: true, length: { maximum: 80 }
  validates :token_digest, presence: true, uniqueness: true
  validate :limite_de_tokens_ativos, on: :create

  scope :ativos, -> { where(revogado_em: nil) }

  # Token em texto puro. Só existe na instância devolvida por .gerar!.
  attr_reader :token

  # Cria um token novo para o usuário e devolve o registro com #token preenchido.
  def self.gerar!(user:, nome:)
    token = "#{PREFIXO}#{SecureRandom.urlsafe_base64(32)}"
    registro = create!(
      user: user,
      nome: nome.to_s.strip,
      token_digest: digest(token),
      token_prefixo: token[0, PREFIXO.length + 6]
    )
    registro.instance_variable_set(:@token, token)
    registro
  end

  # Encontra o token ativo correspondente ao texto puro, ou nil.
  def self.autenticar(token)
    return nil unless token.is_a?(String) && token.start_with?(PREFIXO)

    registro = ativos.includes(:user).find_by(token_digest: digest(token))
    registro&.registrar_uso!
    registro
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def self.formato_de_token?(token)
    token.is_a?(String) && token.start_with?(PREFIXO)
  end

  def revogar!
    update!(revogado_em: Time.current) unless revogado?
  end

  def revogado?
    revogado_em.present?
  end

  def registrar_uso!
    return if last_used_at.present? && last_used_at > INTERVALO_REGISTRO_USO.ago

    update_column(:last_used_at, Time.current)
  end

  def as_json(_options = {})
    {
      id: id,
      nome: nome,
      token_prefixo: token_prefixo,
      last_used_at: last_used_at,
      revogado_em: revogado_em,
      created_at: created_at
    }
  end

  private

  def limite_de_tokens_ativos
    return unless user

    if user.api_tokens.ativos.count >= MAX_ATIVOS_POR_USUARIO
      errors.add(:base, "Você pode ter no máximo #{MAX_ATIVOS_POR_USUARIO} tokens ativos. Revogue um para criar outro.")
    end
  end
end
