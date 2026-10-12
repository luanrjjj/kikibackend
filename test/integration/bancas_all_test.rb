require "test_helper"

# /api/bancas/all alimenta os filtros de Concursos e Provas e não pode exigir admin.
class BancasAllTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "all é acessível sem login" do
    get "/api/bancas/all"
    assert_response :success
    assert_kind_of Array, JSON.parse(response.body)
  end

  test "all é acessível para usuário comum logado" do
    user = User.create!(email: "t_#{SecureRandom.hex(4)}@example.com", password: "password")
    token = user.sessions.create!(expires_at: 1.day.from_now).token

    get "/api/bancas/all", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
  end

  test "create continua exigindo admin" do
    post "/api/bancas", params: { banca: { nome: "X" } }
    assert_response :unauthorized
  end
end
