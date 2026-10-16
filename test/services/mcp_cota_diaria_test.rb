require "test_helper"

class McpCotaDiariaTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(email: "cota-#{SecureRandom.hex(4)}@teste.com", password: "senha-segura-123")
  end

  test "concede até o limite e depois esgota" do
    cota = McpCotaDiaria.new(@user, limite: 150)

    assert_equal 100, cota.reservar!(100)
    assert_equal 50, cota.reservar!(100), "concede só o que resta"
    assert_equal 0, cota.restantes
    assert_raises(McpCotaDiaria::Esgotada) { cota.reservar!(1) }
  end

  test "devolver repõe a cota sem ficar negativa" do
    cota = McpCotaDiaria.new(@user, limite: 10)
    cota.reservar!(8)
    cota.devolver!(3)
    assert_equal 5, cota.usadas

    cota.devolver!(50)
    assert_equal 0, cota.usadas
  end

  test "reservar zero não cria uso nem esgota" do
    cota = McpCotaDiaria.new(@user, limite: 0)
    assert_equal 0, cota.reservar!(0)
  end

  test "a contagem é por dia no horário de Brasília" do
    cota = McpCotaDiaria.new(@user, limite: 5)
    travel_to Time.utc(2026, 10, 16, 2, 30) do # 23:30 do dia 15 em Brasília
      cota.reservar!(5)
      assert_equal Date.new(2026, 10, 15), McpCotaDiaria.hoje
    end
    travel_to Time.utc(2026, 10, 16, 3, 1) do # 00:01 do dia 16
      assert_equal 5, cota.reservar!(5)
    end
  end

  test "resumo mostra uso e renovação" do
    cota = McpCotaDiaria.new(@user)
    cota.reservar!(30)
    resumo = cota.resumo
    assert_equal 1000, resumo[:limite_diario]
    assert_equal 30, resumo[:usadas_hoje]
    assert_equal 970, resumo[:restantes_hoje]
    assert_equal 100, resumo[:max_por_chamada]
  end
end
