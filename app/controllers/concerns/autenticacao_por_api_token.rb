# Autenticação para as rotas que a IA do usuário chama (MCP e questões para Anki).
#
# Aceita o token pessoal (apl_...) gerado no perfil. Com
# `aceitar_sessao: true`, também aceita o token de sessão normal do site, para o
# próprio frontend poder usar a mesma rota.
#
# Tokens pessoais NÃO funcionam no resto da API: o authenticate_user! do
# ApplicationController só conhece a tabela de sessões. Assim, um token colado
# num cliente de IA não consegue apagar cadernos, mexer em pagamentos ou gerar
# outros tokens.
module AutenticacaoPorApiToken
  extend ActiveSupport::Concern

  LIMITE_REQUISICOES_POR_MINUTO = 60

  included do
    attr_reader :current_api_token
  end

  private

  def bearer_token
    header = request.headers['Authorization'].to_s
    header.start_with?('Bearer ') ? header.delete_prefix('Bearer ').strip : header.split(' ').last
  end

  def authenticate_api_token!(aceitar_sessao: false)
    token = bearer_token

    if token.blank?
      return negar_acesso_por_token('Autenticação necessária', 'Envie o token pessoal no cabeçalho Authorization: Bearer <token>.')
    end

    if ApiToken.formato_de_token?(token)
      @current_api_token = ApiToken.autenticar(token)
      return negar_acesso_por_token('Token inválido ou revogado', 'Gere um novo token em Configurações > Acesso por IA.') unless @current_api_token

      @current_user = @current_api_token.user
      limitar_requisicoes_do_token!
    elsif aceitar_sessao
      session = Session.includes(:user).find_by(token: token)
      return negar_acesso_por_token('Sessão inválida ou expirada', 'Sua sessão expirou. Por favor, faça login novamente.') unless session && session.expires_at > Time.current

      @current_user = session.user
    else
      negar_acesso_por_token('Token inválido', 'Use um token pessoal gerado em Configurações > Acesso por IA.')
    end
  end

  def authenticate_api_token_ou_sessao!
    authenticate_api_token!(aceitar_sessao: true)
  end

  # Limite simples por token, usando o cache do Rails (Redis em produção).
  # Se o cache não estiver disponível (ex.: null_store em dev), não limita.
  def limitar_requisicoes_do_token!
    return unless @current_api_token

    chave = "api_token:rl:#{@current_api_token.id}:#{Time.current.to_i / 60}"
    contagem = Rails.cache.increment(chave, 1, expires_in: 2.minutes)
    return if contagem.nil? || contagem <= LIMITE_REQUISICOES_POR_MINUTO

    response.set_header('Retry-After', '60')
    render json: {
      error: 'Limite de requisições atingido',
      message: "Máximo de #{LIMITE_REQUISICOES_POR_MINUTO} requisições por minuto por token. Tente de novo em instantes."
    }, status: :too_many_requests
  rescue StandardError => e
    Rails.logger.warn("[API TOKEN] Falha ao aplicar limite de requisições: #{e.class}: #{e.message}")
  end

  # MCP, questões para Anki e tokens pessoais são só para assinantes
  # (admin conta como assinante, como em User#subscribed?).
  def exigir_plano_pago!
    return if performed? || current_user&.subscribed?

    render json: {
      error: 'subscription_required',
      message: 'O acesso por IA (MCP e questões para Anki) é exclusivo para assinantes. Assine um plano no Apolo para usar.'
    }, status: :forbidden
  end

  def negar_acesso_por_token(erro, mensagem)
    response.set_header('WWW-Authenticate', 'Bearer realm="apolo"')
    render json: { error: erro, message: mensagem }, status: :unauthorized
  end
end
