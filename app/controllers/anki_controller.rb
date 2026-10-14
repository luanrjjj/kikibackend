require 'genanki/package'
require 'genanki/deck'
require 'genanki/model'
require 'genanki/note'

class AnkiController < ApplicationController
  # Exportar um .apkg conta no limite semanal do plano (anki_export_by_week_free).
  before_action :verify_export_limit, only: %i[ generate generate_ai create_export ]
  # Flashcards de conceitos gerados por IA são do plano Pro.
  before_action -> { exigir_recurso!('ia_concept_question_extraction_advanced') }, only: %i[ generate_ai ai_generate_json ]
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

    file_name = "anki_deck_#{Time.now.to_i}.apkg"
    file_path = Rails.root.join('tmp', file_name)
    AnkiDeckBuilder.write(questoes, title, file_path)

    # Registrar a exportação no banco de dados
    Export.create!(
      user: current_user,
      prova_id: prova_id,
      concurso_id: concurso_id,
      questoes_count: questoes.length
    )

    send_file file_path, type: 'application/apkg', disposition: 'attachment', filename: file_name
  end

  # POST /anki/exports — exportação em fila (AnkiExportJob).
  # Mesmo corpo de /anki/generate; responde 202 com o id para acompanhar.
  def create_export
    questoes = params.to_unsafe_h['questoes']
    if questoes.blank? || !questoes.is_a?(Array)
      return render json: { error: 'Nenhuma questão fornecida' }, status: :bad_request
    end

    first_q = questoes.first || {}
    titulo = params[:title].presence || "Anki Deck #{Time.now.strftime('%Y-%m-%d')}"

    export = Export.create!(
      user: current_user,
      prova_id: params[:prova_id].presence || first_q['prova_id'],
      concurso_id: params[:concurso_id].presence || first_q['concurso_id'],
      questoes_count: questoes.length,
      status: 'pendente',
      titulo: titulo,
      payload: { 'title' => titulo, 'questoes' => questoes }
    )

    AnkiExportJob.perform_later(export.id)
    render json: export.as_status_json, status: :accepted
  end

  # GET /anki/exports/:id
  def show_export
    export = current_user.exports.find(params[:id])
    render json: export.as_status_json
  end

  # GET /anki/exports/:id/download
  def download_export
    export = current_user.exports.find(params[:id])
    unless export.concluido? && export.arquivo_key.present?
      return render json: { error: 'export_not_ready', status: export.status }, status: :conflict
    end

    data = SpacesService.read_file(export.arquivo_key)
    nome = "#{export.titulo.to_s.parameterize.presence || 'anki_deck'}.apkg"
    send_data data, type: 'application/apkg', disposition: 'attachment', filename: nome
  end

  def ai_generate_json
    question_data = params[:question]

    if question_data.blank?
      render json: { error: 'Dados da questão não fornecidos' }, status: :bad_request
      return
    end

    questao = Questao.find_by(id: question_data['id'])
    # O cache pode ter sido salvo em outro formato (ex.: { "flashcards": [...] }
    # do DeepSeek); normaliza e, se não sobrar nenhum card, gera de novo.
    ai_cards = questao ? AiService.normalizar_cards(questao.ia_conceito_extracao) : []

    if ai_cards.present?
      questao.update_column(:ia_conceito_extracao, ai_cards) if questao.ia_conceito_extracao != ai_cards
    else
      enunciado = question_data['enunciado']
      texto_apoio = question_data.dig('texto', 'texto')

      # Encontrar o texto da alternativa correta
      # Se a questão não tem 'correta' definida, tenta pegar da resolução do usuário
      correta_value = question_data['correta'] || question_data.dig('resolucao', 'resposta')
      alternativas = question_data['alternativas'] || []
      alternativa_correta = alternativas.find { |a| a['value'] == correta_value }
      resposta_correta = alternativa_correta ? alternativa_correta['text'] : correta_value

      ai_cards = AiService.generate_cards(enunciado, texto_apoio, resposta_correta)

      if ai_cards.blank?
        render json: { error: 'Falha ao gerar cards com IA' }, status: :service_unavailable
        return
      end

      questao.update!(ia_conceito_extracao: ai_cards) if questao
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

    ai_cards = AiService.generate_cards(enunciado, texto_apoio, resposta_correta)

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
