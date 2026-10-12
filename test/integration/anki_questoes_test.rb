require "test_helper"

class AnkiQuestoesTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      email: "anki_#{SecureRandom.hex(4)}@example.com", password: "password",
      subscription_status: "ACTIVE", current_period_end: 1.month.from_now
    )
    @token = ApiToken.gerar!(user: @user, nome: "teste").token
    @q1 = Questao.create!(enunciado: "Q1", ano: 2023, discursiva: false,
                          alternativas: [{ "value" => "C", "text" => "Certo" }, { "value" => "E", "text" => "Errado" }], correta: "C")
    @q2 = Questao.create!(enunciado: "Q2", ano: 2024, discursiva: false,
                          alternativas: [{ "value" => "A", "text" => "x" }, { "value" => "B", "text" => "y" }], correta: "A")
  end

  def auth(token = @token)
    { "Authorization" => "Bearer #{token}" }
  end

  test "uma questão por id" do
    get "/api/anki/questoes/#{@q1[:id]}", headers: auth
    assert_response :success
    corpo = JSON.parse(response.body)
    assert_equal @q1[:id], corpo["id"]
    assert_equal "certo_errado", corpo["tipo"]
    assert_equal "Certo", corpo.dig("gabarito", "texto")
  end

  test "várias questões, na ordem pedida, com as não encontradas" do
    get "/api/anki/questoes", params: { ids: "#{@q2[:id]},#{@q1[:id]},999999" }, headers: auth
    assert_response :success
    corpo = JSON.parse(response.body)
    assert_equal [@q2[:id], @q1[:id]], corpo["questoes"].map { |q| q["id"] }
    assert_equal [999_999], corpo["nao_encontradas"]
  end

  test "POST com lista de ids e sessão do site" do
    sessao = @user.sessions.create!(expires_at: 1.day.from_now)
    post "/api/anki/questoes", params: { ids: [@q1[:id]] }.to_json,
                               headers: auth(sessao.token).merge("Content-Type" => "application/json")
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["total"]
  end

  test "exige plano pago, também com a sessão do site" do
    gratuito = User.create!(email: "free_#{SecureRandom.hex(4)}@example.com", password: "password")
    sessao = gratuito.sessions.create!(expires_at: 1.day.from_now)
    get "/api/anki/questoes/#{@q1[:id]}", headers: auth(sessao.token)
    assert_response :forbidden
  end

  test "valida ids e autenticação" do
    get "/api/anki/questoes", headers: auth
    assert_response :bad_request

    get "/api/anki/questoes", params: { ids: (1..101).to_a.join(",") }, headers: auth
    assert_response :unprocessable_entity

    get "/api/anki/questoes/#{@q1[:id]}"
    assert_response :unauthorized
  end
end
