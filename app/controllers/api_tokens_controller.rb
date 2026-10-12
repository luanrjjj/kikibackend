# Tokens pessoais do usuário logado (tela Configurações > Acesso por IA).
#
# Usa a autenticação normal por sessão: um token pessoal não consegue listar,
# criar nem revogar tokens. Criar exige mcp_access no plano; listar e revogar
# não, para quem perdeu o acesso ainda conseguir apagar tokens antigos.
class ApiTokensController < ApplicationController
  include AutenticacaoPorApiToken

  before_action :exigir_acesso_mcp!, only: :create

  # GET /api/api_tokens  (lista com 0 ou 1 token)
  def index
    tokens = current_user.api_tokens.ativos.order(created_at: :desc)
    render json: tokens
  end

  # POST /api/api_tokens  { api_token: { nome: "Claude no notebook" } }
  # Substitui o token ativo, se houver.
  def create
    nome = params.dig(:api_token, :nome).presence || params[:nome].presence || 'Token de acesso'
    registro = ApiToken.gerar!(user: current_user, nome: nome)

    # O token em texto puro só sai nesta resposta.
    render json: registro.as_json.merge(token: registro.token), status: :created
  end

  # DELETE /api/api_tokens/:id
  def destroy
    registro = current_user.api_tokens.find(params[:id])
    registro.revogar!
    head :no_content
  end
end
