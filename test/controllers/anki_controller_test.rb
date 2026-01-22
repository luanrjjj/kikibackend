require "test_helper"
require "tempfile"

class AnkiControllerTest < ActionDispatch::IntegrationTest
  test "should generate anki deck with basic and cloze cards" do
    questoes = [
      {
        "enunciado" => "Qual é a capital da França?",
        "texto" => "",
        "alternativas" => [
          {"value" => "A", "text" => "Londres"},
          {"value" => "B", "text" => "Paris"},
          {"value" => "C", "text" => "Berlin"}
        ],
        "correta" => "B",
        "type" => "basic"
      },
      {
        "texto" => "O céu é {{c1::azul}}.",
        "extra" => "O sol é amarelo.",
        "type" => "cloze"
      }
    ]

    post anki_generate_url, params: { questoes: questoes }

    assert_response :success
    assert_equal "application/apkg", @response.media_type
  end

  test "should generate deck with reversed and image occlusion cards" do
    # Create a dummy image file for the test
    image = Tempfile.new(['test', '.jpg'])
    image.write("dummy image data")
    image.close

    questoes = [
      {
        "type" => "basic_and_reversed",
        "enunciado" => "Front of the card",
        "resposta" => "Back of the card"
      },
      {
        "type" => "image_occlusion",
        "image_path" => image.path,
        "masks" => "some mask data",
        "header" => "some header",
        "footer" => "some footer"
      }
    ]

    post anki_generate_url, params: { questoes: questoes }

    assert_response :success
    assert_equal "application/apkg", @response.media_type
  ensure
    image.unlink if image
  end

  test "should return bad request if no questoes are provided" do
    post anki_generate_url, params: { questoes: [] }
    assert_response :bad_request
  end
end
