require 'genanki/package'
require 'genanki/deck'
require 'genanki/model'
require 'genanki/note'

class AnkiController < ApplicationController
  before_action :verify_export_limit
  def generate
    questoes = params[:questoes]
    title = params[:title] || "Anki Deck #{Time.now.strftime('%Y-%m-%d')}"

    if questoes.blank?
      render json: { error: 'Nenhuma questão fornecida' }, status: :bad_request
      return
    end

    first_q = questoes.first
    prova_id = params[:prova_id] || first_q['prova_id']
    concurso_id = params[:concurso_id] || first_q['concurso_id']

    # Map to hold decks by name (to support sub-decks by subject)
    decks = {}
    
    # Base deck for everything else
    base_deck_id = Time.now.to_i
    
    models = {}
    media_files = []

    questoes.each_with_index do |q, idx|
      # Determine deck name hierarchy: "Title::Disciplina::Subject"
      disciplina = q['disciplina']
      subject = q['assunto']
      
      hierarchy = [title]
      hierarchy << disciplina if disciplina.present?
      hierarchy << subject if subject.present?
      
      deck_name = hierarchy.join("::")
      
      unless decks.key?(deck_name)
        decks[deck_name] = Genanki::Deck.new(
          deck_id: base_deck_id + idx, # Ensure unique IDs
          name: deck_name
        )
      end
      
      current_deck = decks[deck_name]

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
        end
        models[card_type] = model
      end

      # Prepare tags (no spaces allowed)
      tags = []
      tags << q['disciplina'].gsub(/\s+/, '_') if q['disciplina'].present?
      tags << q['assunto'].gsub(/\s+/, '_') if q['assunto'].present?

      note = nil
      if card_type == 'basic'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['correta']],
          tags: tags
        )
      elsif card_type == 'basic_and_reversed'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['resposta']],
          tags: tags
        )
      elsif card_type == 'cloze'
        note = Genanki::Note.new(
          model: model,
          fields: [q['enunciado'], q['extra']],
          tags: tags
        )
      end

      current_deck.add_note(note) if note
    end

    pkg = Genanki::Package.new(decks.values, media_files: media_files)
    file_name = "anki_deck_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)

    pkg.write_to_file(file_path)

    # Registrar a exportação no banco de dados
    Export.create!(
      user: current_user,
      prova_id: prova_id,
      concurso_id: concurso_id,
      questoes_count: questoes.length
    )

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end

  def ai_generate_json
    question_data = params[:question]

    if question_data.blank?
      render json: { error: 'Dados da questão não fornecidos' }, status: :bad_request
      return
    end

    enunciado = question_data['enunciado']
    texto_apoio = question_data.dig('texto', 'texto')

    # Encontrar o texto da alternativa correta
    # Se a questão não tem 'correta' definida, tenta pegar da resolução do usuário
    correta_value = question_data['correta'] || question_data.dig('resolucao', 'resposta')
    alternativas = question_data['alternativas'] || []
    alternativa_correta = alternativas.find { |a| a['value'] == correta_value }
    resposta_correta = alternativa_correta ? alternativa_correta['text'] : correta_value

    ai_cards = GeminiService.generate_cards(enunciado, texto_apoio, resposta_correta)

    if ai_cards.blank?
      render json: { error: 'Falha ao gerar cards com IA' }, status: :service_unavailable
      return
    end

    render json: { cards: ai_cards }
  end

  def generate_ai
    question_data = params[:question]
    
    if question_data.blank?
      render json: { error: 'Dados da questão não fornecidos' }, status: :bad_request
      return
    end

    enunciado = question_data['enunciado']
    texto_apoio = question_data.dig('texto', 'texto')
    
    # Encontrar o texto da alternativa correta
    # Se a questão não tem 'correta' definida, tenta pegar da resolução do usuário
    correta_value = question_data['correta'] || question_data.dig('resolucao', 'resposta')
    alternativas = question_data['alternativas'] || []
    alternativa_correta = alternativas.find { |a| a['value'] == correta_value }
    resposta_correta = alternativa_correta ? alternativa_correta['text'] : correta_value

    ai_cards = GeminiService.generate_cards(enunciado, texto_apoio, resposta_correta)

    if ai_cards.blank?
      render json: { error: 'Falha ao gerar cards com IA' }, status: :service_unavailable
      return
    end

    # For AI, we can also support sub-decks if discipline/subject is passed
    title = "IA Anki - #{Time.now.strftime('%Y-%m-%d')}"
    disciplina = question_data.dig('disciplina', 'nome') || question_data['disciplina']
    subject = question_data.dig('assunto', 'nome') || question_data['assunto']
    
    hierarchy = [title]
    hierarchy << disciplina if disciplina.present?
    hierarchy << subject if subject.present?
    
    deck_name = hierarchy.join("::")

    deck = Genanki::Deck.new(
      deck_id: Time.now.to_i,
      name: deck_name
    )

    model = Genanki::Model.new(
      model_id: 1699392323,
      name: 'AIQuestaoModel',
      fields: [
        { 'name' => 'Enunciado' },
        { 'name' => 'Resposta' }
      ],
      templates: [
        {
          'name' => 'Card 1',
          'qfmt' => "<div class=\"container\">\n  <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;\">\n    <div class=\"badge\">IA - Pergunta</div>\n    <span style=\"color: #5522fa; font-weight: 600; font-size: 14px;\">APOLO</span>\n  </div>\n  <div class=\"question\">{{Enunciado}}</div>\n</div>",
          'afmt' => "<div class=\"container\">\n  <div style=\"display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;\">\n    <div class=\"badge\">IA - Pergunta</div>\n    <span style=\"color: #5522fa; font-weight: 600; font-size: 14px;\">APOLO</span>\n  </div>\n  <div class=\"question\">{{Enunciado}}</div>\n  <hr id=\"answer\" class=\"divider\">\n  <div class=\"badge\" style=\"background-color: #5522fa; color: white;\">IA - Resposta</div>\n  <div class=\"answer\">{{Resposta}}</div>\n</div>"
        }
      ],
      css: ".card {\n  font-family: 'Moniker', system-ui, -apple-system, sans-serif;\n  font-size: 18px;\n  text-align: left;\n  color: #3f3f46;\n  background-color: #f8fafc;\n  padding: 20px;\n}\n\n.container {\n  background-color: white;\n  border-radius: 12px;\n  border: 1px solid #e4e4e7;\n  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);\n  padding: 24px;\n  max-width: 600px;\n  margin: 0 auto;\n}\n\n.badge {\n  display: inline-flex;\n  padding: 4px 12px;\n  border-radius: 9999px;\n  background-color: rgba(85, 34, 250, 0.1);\n  color: #5522fa;\n  font-size: 10px;\n  font-weight: bold;\n  text-transform: uppercase;\n  letter-spacing: 0.05em;\n  margin-bottom: 12px;\n}\n\n.question {\n  font-weight: 800;\n  font-size: 1.25em;\n  line-height: 1.4;\n  color: #18181b;\n  letter-spacing: -0.025em;\n}\n\n.divider {\n  border: none;\n  border-top: 1px solid #e4e4e7;\n  margin: 20px 0;\n}\n\n.answer {\n  color: #3f3f46;\n  line-height: 1.6;\n  font-weight: 500;\n}\n"
    )

    # Tags for AI cards
    disciplina = question_data.dig('disciplina', 'nome') || question_data['disciplina']
    tags = ["IA_Generated"]
    tags << disciplina.gsub(/\s+/, '_') if disciplina.present?
    tags << subject.gsub(/\s+/, '_') if subject.present?

    ai_cards.each do |card|
      note = Genanki::Note.new(
        model: model,
        fields: [card['front'], card['back']],
        tags: tags
      )
      deck.add_note(note)
    end

    pkg = Genanki::Package.new(deck)
    file_name = "anki_ai_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)
    pkg.write_to_file(file_path)

    # Registrar a exportação
    Export.create!(
      user: current_user,
      prova_id: question_data['prova_id'],
      concurso_id: question_data['concurso_id'],
      questoes_count: ai_cards.length
    )

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end
end
