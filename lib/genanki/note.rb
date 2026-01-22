require 'set'
require_relative 'card'
require_relative 'util'

module GenankiApp
  class Note
    attr_accessor :model, :fields, :due
    attr_writer :tags, :sort_field, :guid

    def initialize(model: nil, fields: nil, sort_field: nil, tags: nil, guid: nil, due: 0)
      @model = model
      @fields = fields
      @sort_field = sort_field
      @tags = tags || []
      @guid = guid
      @due = due
    end

    def sort_field
      @sort_field || @fields[@model.sort_field_index]
    end

    def tags
      @tags
    end

    def tags=(val)
      val.each do |tag|
        raise ArgumentError, "Tag '#{tag}' contains a space; this is not allowed!" if tag.include?(' ')
      end
      @tags = val
    end

    def cards
      @cards ||= begin
        if @model.model_type == GenankiApp::Model::FRONT_BACK
          _front_back_cards
        elsif @model.model_type == GenankiApp::Model::CLOZE
          _cloze_cards
        else
          raise ArgumentError, 'Expected model_type CLOZE or FRONT_BACK'
        end
      end
    end

    def guid
      @guid ||= GenankiApp::Util.guid_for(*@fields)
    end

    def write_to_db(cursor, timestamp, deck_id, id_gen)
      _check_number_model_fields_matches_num_fields
      _check_invalid_html_tags_in_fields

      cursor.execute('INSERT INTO notes VALUES(?,?,?,?,?,?,?,?,?,?,?)', [
        id_gen.next,
        guid,
        @model.model_id,
        timestamp.to_i,
        -1,
        _format_tags,
        _format_fields,
        sort_field,
        0,
        0,
        ''
      ])

      note_id = cursor.last_insert_row_id

      cards.each do |card|
        card.write_to_db(cursor, timestamp, deck_id, note_id, id_gen, due: @due)
      end
    end

    private

    def _cloze_cards
      card_ords = Set.new
      qfmt = @model.templates[0]['qfmt']

      cloze_replacements = qfmt.scan(/{{[^}]*?cloze:(?:[^}]?:)*(.+?)}}/).flatten
      cloze_replacements += qfmt.scan(/<%cloze:(.+?)%>/).flatten

      cloze_replacements.uniq.each do |field_name|
        field_index = @model.fields.index { |f| f['name'] == field_name }
        next unless field_index

        field_value = @fields[field_index] || ""

        matches = field_value.scan(/{{c(\d+)::.+?}}/m).flatten
        matches.each do |m|
          ord = m.to_i - 1
          card_ords.add(ord) if ord >= 0
        end
      end

      # card_ords.add(0) if card_ords.empty?

      card_ords.map { |ord| GenankiApp::Card.new(ord) }
    end

    def _front_back_cards
      rv = []
      @model.req.each do |card_ord, any_or_all, required_field_ords|
        present_fields = required_field_ords.map { |ord| @fields[ord] && !@fields[ord].empty? }

        if any_or_all == 'any'
          rv << GenankiApp::Card.new(card_ord) if present_fields.any?
        elsif any_or_all == 'all'
          rv << GenankiApp::Card.new(card_ord) if present_fields.all?
        end
      end
      rv
    end

    def _check_number_model_fields_matches_num_fields
      if @model.fields.length != @fields.length
        raise ArgumentError, "Number of fields in Model does not match number of fields in Note: #{@model} has #{@model.fields.length} fields, but Note has #{@fields.length} fields."
      end
    end

    def _check_invalid_html_tags_in_fields
      regex = /<(?!\/?[a-zA-Z0-9]+(?: .*|\/?)>|!--|!\[CDATA\[)(?:.|\n)*?>/
      @fields.each do |field|
        if field =~ regex
          warn "Field contained invalid HTML tags. Make sure you are calling html.escape() if your field data isn't already HTML-encoded: #{field}"
        end
      end
    end

    def _format_fields
      @fields.join("\x1f")
    end

    def _format_tags
      " " + @tags.join(" ") + " "
    end
  end
end