require "test_helper"

class PlanosTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    Plano.delete_all
  end

  def usuario(**attrs)
    User.create!({ email: "u_#{SecureRandom.hex(4)}@example.com", password: "password" }.merge(attrs))
  end

  def assinante(plan)
    usuario(plan: plan, subscription_status: "ACTIVE", current_period_end: 1.month.from_now)
  end

  def auth(user)
    { "Authorization" => "Bearer #{user.sessions.create!(expires_at: 1.day.from_now).token}" }
  end

  test "plano gratuito para no limite de resoluções" do
    Plano.create!(nome_do_plano: "Free", variaveis: ["limit_resolutions_free:2"])
    user = usuario
    questao = Questao.create!(enunciado: "Q", ano: 2024, discursiva: false, correta: "A")

    2.times do
      post "/api/resolucoes", params: { resolucao: { questao_id: questao[:id], resposta: "A" } }, headers: auth(user)
      assert_response :created
    end

    post "/api/resolucoes", params: { resolucao: { questao_id: questao[:id], resposta: "A" } }, headers: auth(user)
    assert_response :forbidden
    corpo = JSON.parse(response.body)
    assert_equal "upgrade_required", corpo["error"]
    assert_equal "limit_resolutions_free", corpo["recurso"]
    assert_equal 2, corpo["limite"]
  end

  test "guias exigem guide_access" do
    get "/api/guias/999999", headers: auth(usuario)
    assert_response :forbidden
    assert_equal "guide_access", JSON.parse(response.body)["recurso"]

    # Passou da checagem do plano; o guia é que não existe.
    get "/api/guias/999999", headers: auth(assinante("BASIC"))
    assert_response :not_found
  end

  test "lista completa de guias é só do admin" do
    get "/api/guias", headers: auth(assinante("PRO"))
    assert_response :forbidden
  end

  test "token pessoal exige mcp_access" do
    post "/api/api_tokens", params: { api_token: { nome: "x" } }, headers: auth(assinante("BASIC"))
    assert_response :forbidden
    assert_equal "mcp_access", JSON.parse(response.body)["recurso"]

    post "/api/api_tokens", params: { api_token: { nome: "x" } }, headers: auth(assinante("PRO"))
    assert_response :created
  end

  test "sessão devolve o nível do plano" do
    user = assinante("BASIC")
    assert_equal :basic, user.plano_nivel
    assert_equal "basic", user.to_session_json["plano_nivel"].to_s
  end
end
