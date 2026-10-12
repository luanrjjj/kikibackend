require "test_helper"

class ApiTokensTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  def sessao_de(user)
    { "Authorization" => "Bearer #{user.sessions.create!(expires_at: 1.day.from_now).token}" }
  end

  test "assinante cria, lista e revoga" do
    user = User.create!(email: "t_#{SecureRandom.hex(4)}@example.com", password: "password",
                        subscription_status: "ACTIVE", current_period_end: 1.month.from_now)
    headers = sessao_de(user)

    post "/api/api_tokens", params: { api_token: { nome: "Claude" } }, headers: headers
    assert_response :created
    criado = JSON.parse(response.body)
    assert criado["token"].start_with?("apl_")

    get "/api/api_tokens", headers: headers
    assert_equal [criado["id"]], JSON.parse(response.body).map { |t| t["id"] }
    assert_nil JSON.parse(response.body).first["token"]

    post "/api/api_tokens", params: { api_token: { nome: "Cursor" } }, headers: headers
    substituto = JSON.parse(response.body)
    get "/api/api_tokens", headers: headers
    assert_equal [substituto["id"]], JSON.parse(response.body).map { |t| t["id"] }

    delete "/api/api_tokens/#{substituto["id"]}", headers: headers
    assert_response :no_content
    get "/api/api_tokens", headers: headers
    assert_empty JSON.parse(response.body)
  end

  test "plano gratuito não cria token, mas pode listar" do
    user = User.create!(email: "f_#{SecureRandom.hex(4)}@example.com", password: "password")
    headers = sessao_de(user)

    post "/api/api_tokens", params: { api_token: { nome: "x" } }, headers: headers
    assert_response :forbidden

    get "/api/api_tokens", headers: headers
    assert_response :success
  end

  test "token pessoal não gerencia tokens" do
    user = User.create!(email: "p_#{SecureRandom.hex(4)}@example.com", password: "password",
                        subscription_status: "ACTIVE", current_period_end: 1.month.from_now)
    token = ApiToken.gerar!(user: user, nome: "x").token

    get "/api/api_tokens", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end
end
