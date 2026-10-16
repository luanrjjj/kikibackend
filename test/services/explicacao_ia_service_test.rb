require "test_helper"

class ExplicacaoIaServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normaliza a resposta da IA" do
    dados = ExplicacaoIaService.normalizar(
      "Resumo" => " Cobra X ",
      "gabarito" => "B",
      "explicacao" => "Porque sim",
      "alternativas" => [
        { "letra" => "A", "correta" => false, "comentario" => "errada" },
        { "letra" => "B", "correta" => "true", "comentario" => "certa" },
        { "letra" => "", "comentario" => "sem letra" },
        "lixo"
      ],
      "conceitos" => ["c1", 5, ""],
      "dica" => ""
    )

    assert_equal "Cobra X", dados["resumo"]
    assert_equal %w[A B], dados["alternativas"].map { |a| a["letra"] }
    assert_equal [false, true], dados["alternativas"].map { |a| a["correta"] }
    assert_equal ["c1"], dados["conceitos"]
    refute dados.key?("dica")
  end

  test "resposta sem explicação nem alternativas é inválida" do
    assert_nil ExplicacaoIaService.normalizar(nil)
    assert_nil ExplicacaoIaService.normalizar("texto")
    assert_nil ExplicacaoIaService.normalizar("resumo" => "só o resumo")
  end

  test "provedor desconhecido" do
    assert ExplicacaoIaService.provedor_valido?("deepseek")
    refute ExplicacaoIaService.provedor_valido?("gpt")
  end
end
