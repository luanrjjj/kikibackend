require 'json'

module GenankiApp
  class Deck
    attr_accessor :deck_id, :name, :description, :notes, :models

    def initialize(deck_id: nil, name: nil, description: '')
      @deck_id = deck_id
      @name = name
      @description = description
      @notes = []
      @models = {} # map of model id to model
    end

    def add_note(note)
      @notes << note
    end

    def add_model(model)
      @models[model.model_id] = model
    end

    def to_json
      {
        "collapsed" => false,
        "conf" => 1,
        "desc" => @description,
        "dyn" => 0,
        "extendNew" => 0,
        "extendRev" => 50,
        "id" => @deck_id,
        "lrnToday" => [
          163,
          2
        ],
        "mod" => 1425278051,
        "name" => @name,
        "newToday" => [
          163,
          2
        ],
        "revToday" => [
          163,
          0
        ],
        "timeToday" => [
          163,
          23598
        ],
        "usn" => -1
      }
    end

    def write_to_db(cursor, timestamp, id_gen)
      raise TypeError, "Deck .deck_id must be an integer, not #{@deck_id}." unless @deck_id.is_a?(Integer)
      raise TypeError, "Deck .name must be a string, not #{@name}." unless @name.is_a?(String)

      decks_json_str = cursor.execute('SELECT decks FROM col').first[0]
      decks = JSON.parse(decks_json_str)
      decks[@deck_id.to_s] = to_json
      cursor.execute('UPDATE col SET decks = ?', [decks.to_json])

      models_json_str = cursor.execute('SELECT models from col').first[0]
      models = JSON.parse(models_json_str)

      @notes.each { |note| add_model(note.model) }
      @models.each_value { |model| models[model.model_id.to_s] = model.to_json(timestamp, @deck_id) }

      cursor.execute('UPDATE col SET models = ?', [models.to_json])

      @notes.each { |note| note.write_to_db(cursor, timestamp, @deck_id, id_gen) }
    end

    def write_to_file(file)
      # Write this deck to a .apkg file.
      GenankiApp::Package.new(self).write_to_file(file)
    end
  end
end