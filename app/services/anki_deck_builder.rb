require 'genanki/package'
require 'genanki/deck'
require 'genanki/model'
require 'genanki/note'

# Monta o pacote .apkg do Anki a partir das questões/cards enviados pelo
# frontend. Usado pela exportação síncrona (AnkiController#generate) e pela
# exportação em fila (AnkiExportJob).
#
# questoes: array de hashes com chaves string: enunciado, correta, resposta,
# extra, type (basic | basic_and_reversed | cloze), disciplina, assunto.
class AnkiDeckBuilder
  # on_progress: chamado com (feitas, total) a cada card montado; usado pelo
  # AnkiExportJob para alimentar a barra de progresso do frontend.
  def self.build(questoes, title, on_progress: nil)
    new(questoes, title, on_progress: on_progress).build
  end

  def self.write(questoes, title, path, on_progress: nil)
    build(questoes, title, on_progress: on_progress).write_to_file(path)
    path
  end

  def initialize(questoes, title, on_progress: nil)
    @questoes = Array(questoes).map { |q| q.respond_to?(:to_unsafe_h) ? q.to_unsafe_h : q.to_h }.map(&:stringify_keys)
    @title = title.presence || "Anki Deck #{Time.now.strftime('%Y-%m-%d')}"
    @on_progress = on_progress
  end

  # @return [Genanki::Package]
  def build
    questoes = @questoes
    title = @title

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
      @on_progress&.call(idx + 1, questoes.size)
    end

    Genanki::Package.new(decks.values, media_files: media_files)
  end
end
