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

  test "gerar um token novo revoga o anterior" do
    antigo = ApiToken.gerar!(user: @user, nome: "antigo")
    novo = ApiToken.gerar!(user: @user, nome: "novo")

    assert_equal [novo.id], @user.api_tokens.ativos.pluck(:id)
    assert antigo.reload.revogado?
    assert_nil ApiToken.autenticar(antigo.token)
    assert_equal novo.id, ApiToken.autenticar(novo.token).id
  end

  test "o banco não aceita dois tokens ativos" do
    ApiToken.gerar!(user: @user, nome: "ativo")
    segundo = ApiToken.new(user: @user, nome: "x", token_digest: ApiToken.digest("apl_x"), token_prefixo: "apl_x")

    assert_not segundo.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { segundo.save!(validate: false) }
  end
end
