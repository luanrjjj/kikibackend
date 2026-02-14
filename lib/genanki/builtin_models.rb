require_relative 'model'

module Genanki
  class BuiltinModels
  BASIC_MODEL = Genanki::Model.new(
    model_id: 1559383000,
    name: 'Basic (genanki)',
    fields: [
      { 'name' => 'Front', 'font' => 'Arial' },
      { 'name' => 'Back', 'font' => 'Arial' }
    ],
    templates: [
      {
        'name' => 'Card 1',
        'qfmt' => '{{Front}}',
        'afmt' => '{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}'
      }
    ],
    css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n"
  )

  BASIC_AND_REVERSED_CARD_MODEL = Genanki::Model.new(
    model_id: 1485830179,
    name: 'Basic (and reversed card) (genanki)',
    fields: [
      { 'name' => 'Front', 'font' => 'Arial' },
      { 'name' => 'Back', 'font' => 'Arial' }
    ],
    templates: [
      {
        'name' => 'Card 1',
        'qfmt' => '{{Front}}',
        'afmt' => '{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}'
      },
      {
        'name' => 'Card 2',
        'qfmt' => '{{Back}}',
        'afmt' => '{{FrontSide}}\n\n<hr id=answer>\n\n{{Front}}'
      }
    ],
    css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n"
  )

  BASIC_OPTIONAL_REVERSED_CARD_MODEL = Genanki::Model.new(
    model_id: 1382232460,
    name: 'Basic (optional reversed card) (genanki)',
    fields: [
      { 'name' => 'Front', 'font' => 'Arial' },
      { 'name' => 'Back', 'font' => 'Arial' },
      { 'name' => 'Add Reverse', 'font' => 'Arial' }
    ],
    templates: [
      {
        'name' => 'Card 1',
        'qfmt' => '{{Front}}',
        'afmt' => '{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}'
      },
      {
        'name' => 'Card 2',
        'qfmt' => '{{#Add Reverse}}{{Back}}{{/Add Reverse}}',
        'afmt' => '{{FrontSide}}\n\n<hr id=answer>\n\n{{Front}}'
      }
    ],
    css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n"
  )

  BASIC_TYPE_IN_THE_ANSWER_MODEL = Genanki::Model.new(
    model_id: 1305534440,
    name: 'Basic (type in the answer) (genanki)',
    fields: [
      { 'name' => 'Front', 'font' => 'Arial' },
      { 'name' => 'Back', 'font' => 'Arial' }
    ],
    templates: [
      {
        'name' => 'Card 1',
        'qfmt' => '{{Front}}\n\n{{type:Back}}',
        'afmt' => '{{Front}}\n\n<hr id=answer>\n\n{{type:Back}}'
      }
    ],
    css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n"
  )

  CLOZE_MODEL = Genanki::Model.new(
    model_id: 1550428389,
    name: 'Cloze (genanki)',
    model_type: Genanki::Model::CLOZE,
    fields: [
      { 'name' => 'Text', 'font' => 'Arial' },
      { 'name' => 'Back Extra', 'font' => 'Arial' }
    ],
    templates: [
      {
        'name' => 'Cloze',
        'qfmt' => '{{cloze:Text}}',
        'afmt' => '{{cloze:Text}}<br>\n{{Back Extra}}'
      }
    ],
    css: ".card {\n font-family: arial;\n font-size: 20px;\n text-align: center;\n color: black;\n background-color: white;\n}\n\n.cloze {\n font-weight: bold;\n color: blue;\n}\n.nightMode .cloze {\n color: lightblue;\n}"
  )

  def self.fix_deprecated_builtin_models_and_warn(model, fields)
    if model == CLOZE_MODEL && fields.length == 1
      fixed_fields = fields + ['']
      warn "Using CLOZE_MODEL with a single field is deprecated. Please pass two fields, e.g. #{fixed_fields.inspect} . See https://github.com/kerrickstaley/genanki#cloze_model-deprecationwarning ."
      return fixed_fields
    end
    fields
  end
  end
end
