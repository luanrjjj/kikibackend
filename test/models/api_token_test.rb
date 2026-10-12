require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  # Algumas fixtures do projeto estão vazias e quebram ao carregar; este teste
  # cria os próprios registros.
  self.fixture_table_names = []

  setup do
    @user = User.create!(email: "token_#{SecureRandom.hex(4)}@example.com", password: "password")
  end

  test "gerar! devolve o token uma vez e guarda só o digest" do
    registro = ApiToken.gerar!(user: @user, nome: "Claude")

    assert registro.token.start_with?(ApiToken::PREFIXO)
    assert_equal ApiToken.digest(registro.token), registro.token_digest
    assert registro.token.start_with?(registro.token_prefixo)
    assert_nil ApiToken.find(registro.id).token
  end

  test "autenticar encontra token ativo e marca o uso" do
    registro = ApiToken.gerar!(user: @user, nome: "Claude")

    encontrado = ApiToken.autenticar(registro.token)
    assert_equal registro.id, encontrado.id
    assert_not_nil encontrado.reload.last_used_at
  end

  test "autenticar recusa token revogado, desconhecido ou de sessão" do
    registro = ApiToken.gerar!(user: @user, nome: "Claude")
    registro.revogar!

    assert_nil ApiToken.autenticar(registro.token)
    assert_nil ApiToken.autenticar("apl_naoexiste")
    assert_nil ApiToken.autenticar(SecureRandom.hex(24))
    assert_nil ApiToken.autenticar(nil)
  end

  test "limita a quantidade de tokens ativos" do
    ApiToken::MAX_ATIVOS_POR_USUARIO.times { |i| ApiToken.gerar!(user: @user, nome: "t#{i}") }

    assert_raises(ActiveRecord::RecordInvalid) { ApiToken.gerar!(user: @user, nome: "um a mais") }

    @user.api_tokens.first.revogar!
    assert ApiToken.gerar!(user: @user, nome: "depois de revogar")
  end
end
