require 'genanki/package'
require 'genanki/deck'
require 'genanki/model'
require 'genanki/note'

class AnkiController < ApplicationController
  def generate
    questoes = params[:questoes]

    if questoes.blank?
      render json: { error: 'Nenhuma questão fornecida' }, status: :bad_request
      return
    end

    deck = Genanki::Deck.new(
      deck_id: Time.now.to_i,
      name: "Anki Deck #{Time.now.strftime('%Y-%m-%d')}"
    )

    models = {}
    media_files = []

    questoes.each do |q|
      card_type = q['type'] || 'basic'
      model = models[card_type]

      if model.nil?
        if card_type == 'basic'
          model = Genanki::Model.new(
            model_id: 1699392319,
            name: 'QuestaoModel',
            fields: [
              { 'name' => 'Enunciado' },
              { 'name' => 'Resposta' }
            ],
            templates: [
              {
                'name' => 'Card 1',
                'qfmt' => "<div class=\"container\">\n  <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;\">\n    <div class=\"badge\">Pergunta</div>\n    <span style=\"color: #5522fa; font-weight: 600; font-size: 14px;\">APOLO</span>\n  </div>\n  <div class=\"question\">{{Enunciado}}</div>\n</div>",
                'afmt' => "<div class=\"container\">\n  <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;\">\n    <div class=\"badge\">Pergunta</div>\n    <span style=\"color: #5522fa; font-weight: 600; font-size: 14px;\">APOLO</span>\n  </div>\n  <div class=\"question\">{{Enunciado}}</div>\n  <hr id=\"answer\" class=\"divider\">\n  <div class=\"badge\" style=\"background-color: #5522fa; color: white;\">Resposta</div>\n  <div class=\"answer\">{{Resposta}}</div>\n</div>"
              }
            ],
            css: ".card {\n  font-family: 'Moniker', system-ui, -apple-system, sans-serif;\n  font-size: 18px;\n  text-align: left;\n  color: #3f3f46;\n  background-color: #f8fafc;\n  padding: 20px;\n}\n\n.container {\n  background-color: white;\n  border-radius: 12px;\n  border: 1px solid #e4e4e7;\n  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);\n  padding: 24px;\n  max-width: 600px;\n  margin: 0 auto;\n}\n\n.badge {\n  display: inline-flex;\n  padding: 4px 12px;\n  border-radius: 9999px;\n  background-color: rgba(85, 34, 250, 0.1);\n  color: #5522fa;\n  font-size: 10px;\n  font-weight: bold;\n  text-transform: uppercase;\n  letter-spacing: 0.05em;\n  margin-bottom: 12px;\n}\n\n.question {\n  font-weight: 800;\n  font-size: 1.25em;\n  line-height: 1.4;\n  color: #18181b;\n  letter-spacing: -0.025em;\n}\n\n.divider {\n  border: none;\n  border-top: 1px solid #e4e4e7;\n  margin: 20px 0;\n}\n\n.answer {\n  color: #3f3f46;\n  line-height: 1.6;\n  font-weight: 500;\n}\n"
          )
        elsif card_type == 'basic_and_reversed'
          model = Genanki::Model.new(
            model_id: 1699392321,
            name: 'QuestaoModelReversed',
            fields: [
              { 'name' => 'Enunciado' },
              { 'name' => 'Resposta' }
            ],
            templates: [
              {
                'name' => 'Card 1',
                'qfmt' => '{{Enunciado}}',
                'afmt' => '{{FrontSide}}<hr id="answer">{{Resposta}}'
              },
              {
                'name' => 'Card 2',
                'qfmt' => '{{Resposta}}',
                'afmt' => '{{FrontSide}}<hr id="answer">{{Enunciado}}'
              }
            ],
            css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\ndetails {\n margin-top: 10px;\n}\nsummary {\n cursor: pointer;\n user-select: none;\n}\n"
          )
        elsif card_type == 'cloze'
          model = Genanki::Model.new(
            model_id: 1699392320, # different model_id
            name: 'ClozeModel',
            model_type: Genanki::Model::CLOZE,
            fields: [
              { 'name' => 'Texto' },
              { 'name' => 'Extra' }
            ],
            templates: [
              {
                'name' => 'Cloze',
                'qfmt' => '{{cloze:Texto}}',
                'afmt' => '{{cloze:Texto}}<br>{{Extra}}'
              }
            ]
          )
        elsif card_type == 'image_occlusion'
          model = Genanki::Model.new(
            model_id: 1699392322,
            name: 'ImageOcclusionModel',
            fields: [
              { 'name' => 'Image' },
              { 'name' => 'Masks' },
              { 'name' => 'Header' },
              { 'name' => 'Footer' }
            ],
            templates: [
              {
                'name' => 'Image Occlusion',
                'qfmt' => '{{Header}}<br><img src="{{Image}}"><br>{{Footer}}',
                'afmt' => '{{FrontSide}}<hr id="answer">{{Masks}}'
              }
            ]
          )
        end
        models[card_type] = model
      end

      note = nil
      if card_type == 'basic'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['correta']]
        )
      elsif card_type == 'basic_and_reversed'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['resposta']]
        )

        #Consertar o q['extra'] parametro, alem disso o cloze precisa ser estilizado.
      elsif card_type == 'cloze'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['extra']]
        )
      elsif card_type == 'image_occlusion'
        # I'm assuming the image is passed as a file path
        # and I'm adding it to media_files to be included in the package.
        if q['image_path'] && File.exist?(q['image_path'])
          media_files << q['image_path']
          image_name = File.basename(q['image_path'])
          note = Genanki::Note.new(
            model: model,
            fields: [image_name, q['masks'], q['header'], q['footer']]
          )
        end
      end

      deck.add_note(note) if note
    end

    pkg = Genanki::Package.new(deck, media_files: media_files)
    file_name = "anki_deck_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)

    pkg.write_to_file(file_path)

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end
end