require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @user = User.create!(email: "mcp_#{SecureRandom.hex(4)}@example.com", password: "password")
    @token = ApiToken.gerar!(user: @user, nome: "teste").token

    disciplina = Disciplina.create!(nome: "Português")
    @questao = Questao.create!(
      enunciado: "<p>Assinale a alternativa <b>correta</b>.</p>",
      ano: 2024,
      discursiva: false,
      disciplina: disciplina,
      alternativas: [{ "value" => "A", "text" => "Primeira" }, { "value" => "B", "text" => "Segunda" }],
      correta: "B"
    )
    @user.resolucoes.create!(questao_id: @questao[:id], resposta: "A", correta: false)
  end

  def rpc(method, params = nil, id: 1, token: @token)
    corpo = { jsonrpc: "2.0", id: id, method: method }
    corpo[:params] = params if params
    post "/api/mcp", params: corpo.to_json, headers: {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream",
      "Authorization" => "Bearer #{token}"
    }
    response.body.present? ? JSON.parse(response.body) : nil
  end

  test "exige token pessoal" do
    post "/api/mcp", params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
    assert_match "Bearer", response.headers["WWW-Authenticate"]
  end

  test "recusa token de sessão do site" do
    sessao = @user.sessions.create!(expires_at: 1.day.from_now)
    rpc("ping", token: sessao.token)
    assert_response :unauthorized
  end

  test "initialize, notificação e lista de ferramentas" do
    resposta = rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "teste", version: "1" } })
    assert_response :success
    assert_equal "2025-06-18", resposta.dig("result", "protocolVersion")

    post "/api/mcp", params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json,
                     headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}" }
    assert_response :accepted

    nomes = rpc("tools/list").dig("result", "tools").map { |t| t["name"] }
    assert_includes nomes, "questoes_para_anki"
    assert_not_includes nomes, "criar_caderno_de_erros"
  end

  test "ferramentas de estatística e questões" do
    resultado = rpc("tools/call", { name: "estatisticas_gerais", arguments: { dias: 7 } })["result"]
    assert_equal false, resultado["isError"]
    assert_equal 1, resultado.dig("structuredContent", "resumo", "total_resolucoes")

    erradas = rpc("tools/call", { name: "questoes_erradas", arguments: {} }).dig("result", "structuredContent", "questoes")
    assert_equal [@questao[:id]], erradas.map { |q| q["id"] }

    anki = rpc("tools/call", { name: "questoes_para_anki", arguments: { ids: [@questao[:id]] } }).dig("result", "structuredContent")
    questao = anki["questoes"].first
    assert_equal "B", questao.dig("gabarito", "letra")
    assert_equal "Segunda", questao.dig("gabarito", "texto")
    assert_equal "Assinale a alternativa correta.", questao["enunciado"]
    assert_equal 1, questao.dig("minha_resolucao", "erros")
  end

  test "erro de argumento volta como isError" do
    resultado = rpc("tools/call", { name: "estatisticas_caderno", arguments: { caderno_id: 999_999 } })["result"]
    assert resultado["isError"]
  end

  test "GET não é permitido" do
    get "/api/mcp"
    assert_response :method_not_allowed
  end
end
