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

    deck = GenankiApp::Deck.new(
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
          model = GenankiApp::Model.new(
            model_id: 1699392319,
            name: 'QuestaoModel',
            fields: [
              { 'name' => 'Enunciado' },
              { 'name' => 'Resposta' }
            ],
            templates: [
              {
                'name' => 'Card 1',
                'qfmt' => '{{Enunciado}}',
                'afmt' => '{{FrontSide}}<hr id="answer">{{Resposta}}'
              }
            ]
          )
        elsif card_type == 'basic_and_reversed'
          model = GenankiApp::Model.new(
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
            ]
          )
        elsif card_type == 'cloze'
          model = GenankiApp::Model.new(
            model_id: 1699392320, # different model_id
            name: 'ClozeModel',
            model_type: GenankiApp::Model::CLOZE,
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
          model = GenankiApp::Model.new(
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
        front = "<strong>#{q['enunciado']}</strong><br><br>#{q['texto']}"

        alternatives_html = "<ul>"
        if q['alternativas'].is_a?(Array)
          q['alternativas'].each do |alt|
             val = alt['value'] || alt[:value]
             txt = alt['text'] || alt[:text]
             alternatives_html += "<li><strong>#{val}</strong>: #{txt}</li>"
          end
        end
        alternatives_html += "</ul>"

        back = "#{alternatives_html}<br><strong>Resposta Correta: #{q['correta']}</strong>"

        note = GenankiApp::Note.new(
          model: model,
          fields: [front, back]
        )
      elsif card_type == 'basic_and_reversed'
        note = GenankiApp::Note.new(
          model: model,
          fields: [q['enunciado'], q['resposta']]
        )
      elsif card_type == 'cloze'
        note = GenankiApp::Note.new(
          model: model,
          fields: [q['texto'], q['extra']]
        )
      elsif card_type == 'image_occlusion'
        # I'm assuming the image is passed as a file path
        # and I'm adding it to media_files to be included in the package.
        if q['image_path'] && File.exist?(q['image_path'])
          media_files << q['image_path']
          image_name = File.basename(q['image_path'])
          note = GenankiApp::Note.new(
            model: model,
            fields: [image_name, q['masks'], q['header'], q['footer']]
          )
        end
      end

      deck.add_note(note) if note
    end

    pkg = GenankiApp::Package.new(deck, media_files: media_files)
    file_name = "anki_deck_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)

    pkg.write_to_file(file_path)

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end
end