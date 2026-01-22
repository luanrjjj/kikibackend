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

    questoes.each do |q|
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
      deck.add_note(note)
    end

    pkg = GenankiApp::Package.new(deck)
    file_name = "anki_deck_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)

    pkg.write_to_file(file_path)

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end
end