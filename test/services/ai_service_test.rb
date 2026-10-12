require "test_helper"

class AiServiceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CARD = { "front" => "Pergunta", "back" => "Resposta" }.freeze

  test "aceita array de cards" do
    assert_equal [CARD], AiService.normalizar_cards([CARD])
  end

  test "aceita objeto com a lista dentro (formato json_object do DeepSeek)" do
    assert_equal [CARD], AiService.normalizar_cards({ "flashcards" => [CARD] })
    assert_equal [CARD], AiService.normalizar_cards({ "cards" => [CARD] })
  end

  test "aceita um card solto e chaves em português" do
    assert_equal [CARD], AiService.normalizar_cards(CARD)
    assert_equal [CARD], AiService.normalizar_cards({ "cards" => [{ "Frente" => "Pergunta", "Verso" => "Resposta" }] })
  end

  test "aceita string JSON e descarta cards incompletos" do
    json = { cards: [CARD, { front: "", back: "x" }] }.to_json
    assert_equal [CARD], AiService.normalizar_cards(json)
  end

  test "valores inválidos viram lista vazia" do
    assert_equal [], AiService.normalizar_cards(nil)
    assert_equal [], AiService.normalizar_cards({})
    assert_equal [], AiService.normalizar_cards("não é json")
  end
end
