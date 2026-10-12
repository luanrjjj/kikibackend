# Endpoint MCP do Apolo: /api/mcp
#
# Exige mcp_access no plano (Pro). O usuário conecta a própria IA com o token pessoal
# gerado em Configurações > Acesso por IA. Exemplo no Claude Code:
#
#   claude mcp add --transport http apolo https://SEU_DOMINIO/api/mcp \
#     --header "Authorization: Bearer apl_..."
#
# Usa o transporte Streamable HTTP da gem `mcp` no modo sem estado e com
# resposta JSON: cada POST é independente, então funciona com vários processos
# Puma e não guarda sessão em memória.
class McpController < ApplicationController
  include AutenticacaoPorApiToken

  skip_before_action :authenticate_user!
  before_action :authenticate_api_token!
  before_action :exigir_acesso_mcp!

  # POST/GET/DELETE /api/mcp
  def handle
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      Mcp::Servidor.construir(current_user),
      stateless: true,
      enable_json_response: true,
      # `render` monta a resposta inteira; não dá para manter um stream SSE aberto.
      serve_subscriptions_listen: false,
      # A proteção contra DNS rebinding da gem só libera localhost por padrão.
      # Ela existe para servidores locais sem autenticação; aqui toda requisição
      # já passou pelo token pessoal antes de chegar ao transporte.
      dns_rebinding_protection: false
    )

    status, headers, body = transport.handle_request(request)
    headers = headers.transform_keys(&:downcase)
    tipo = headers.delete('content-type') || 'application/json'
    headers.each { |nome, valor| response.set_header(nome, valor) }

    conteudo = body.respond_to?(:first) ? body.first : nil
    if conteudo.present?
      render body: conteudo, status: status, content_type: tipo
    else
      head status
    end
  end
end
