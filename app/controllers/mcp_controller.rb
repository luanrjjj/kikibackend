# Endpoint MCP do Apolo: POST /api/mcp
#
# O usuário conecta a própria IA com o token pessoal gerado em
# Configurações > Acesso por IA. Exemplo no Claude Code:
#
#   claude mcp add --transport http apolo https://apoloconcursos.com.br/api/mcp \
#     --header "Authorization: Bearer apl_..."
#
# O servidor não guarda estado entre requisições e só responde em JSON (sem
# SSE). Por isso GET e DELETE devolvem 405, como a especificação permite.
class McpController < ApplicationController
  include AutenticacaoPorApiToken

  skip_before_action :authenticate_user!
  before_action :authenticate_api_token!, only: :handle

  # POST /api/mcp
  def handle
    mensagem = begin
      JSON.parse(request.raw_post.to_s)
    rescue JSON::ParserError
      return render json: Mcp::Servidor.erro_de_parse, status: :bad_request
    end

    resposta = Mcp::Servidor.new(user: current_user).processar(mensagem)

    if resposta.nil?
      # Só havia notificações: nada a responder.
      head :accepted
    else
      render json: resposta
    end
  end

  # GET/DELETE /api/mcp
  def metodo_nao_permitido
    response.set_header('Allow', 'POST')
    head :method_not_allowed
  end
end
