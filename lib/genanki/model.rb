require 'yaml'
require 'mustache'

module Genanki
  class Model
    FRONT_BACK = 0
    CLOZE = 1
    DEFAULT_LATEX_PRE = <<~LATEX
      \\documentclass[12pt]{article}
      \\special{papersize=3in,5in}
      \\usepackage[utf8]{inputenc}
      \\usepackage{amssymb,amsmath}
      \\pagestyle{empty}
      \\setlength{\\parindent}{0in}
      \\begin{document}
    LATEX
    DEFAULT_LATEX_POST = '\\end{document}'

    attr_accessor :model_id, :name, :fields, :templates, :css, :model_type, :latex_pre, :latex_post, :sort_field_index

    def initialize(model_id: nil, name: nil, fields: nil, templates: nil, css: '', model_type: FRONT_BACK, latex_pre: DEFAULT_LATEX_PRE, latex_post: DEFAULT_LATEX_POST, sort_field_index: 0)
      @model_id = model_id
      @name = name
      set_fields(fields)
      set_templates(templates)
      @css = css
      @model_type = model_type
      @latex_pre = latex_pre
      @latex_post = latex_post
      @sort_field_index = sort_field_index
    end

    def set_fields(fields)
      if fields.is_a?(Array)
        @fields = fields
      elsif fields.is_a?(String)
        @fields = YAML.safe_load(fields)
      end
    end

    def set_templates(templates)
      if templates.is_a?(Array)
        @templates = templates
      elsif templates.is_a?(String)
        @templates = YAML.safe_load(templates)
      end
    end

    def req
      return @_req if defined?(@_req)

      if @model_type == CLOZE
        # Special handling for cloze models, which have a syntax that Mustache can't parse.
        # This assumes that the first field is the one with the cloze deletions.
        @_req = @templates.each_with_index.map do |template, i|
          [i, 'any', [0]]
        end
        return @_req
      end

      sentinel = 'SeNtInEl'
      field_names = @fields.map { |f| f['name'] }

      req_list = []

      @templates.each_with_index do |template, template_ord|
        required_fields = []

        # First pass: check for "all" requirement
        field_names.each_with_index do |field_name, field_ord|
          field_values = field_names.map { |f| [f, sentinel] }.to_h
          field_values[field_name] = ''

          rendered = Mustache.render(template['qfmt'], field_values)

          required_fields << field_ord unless rendered.include?(sentinel)
        end

        if !required_fields.empty?
          req_list << [template_ord, 'all', required_fields]
          next
        end

        # Second pass: check for "any" requirement
        field_names.each_with_index do |field_name, field_ord|
          field_values = field_names.map { |f| [f, ''] }.to_h
          field_values[field_name] = sentinel

          rendered = Mustache.render(template['qfmt'], field_values)

          required_fields << field_ord if rendered.include?(sentinel)
        end

        raise "Could not compute required fields for this template; please check the formatting of \"qfmt\": #{template}" if required_fields.empty?

        req_list << [template_ord, 'any', required_fields]
      end

      @_req = req_list
    end

    def to_json(timestamp, deck_id)
      @templates.each_with_index do |tmpl, ord|
        tmpl['ord'] = ord
        tmpl['bafmt'] = '' unless tmpl.key?('bafmt')
        tmpl['bqfmt'] = '' unless tmpl.key?('bqfmt')
        tmpl['bfont'] = '' unless tmpl.key?('bfont')
        tmpl['bsize'] = 0 unless tmpl.key?('bsize')
        tmpl['did'] = nil unless tmpl.key?('did')
      end

      @fields.each_with_index do |field, ord|
        field['ord'] = ord
        field['font'] = 'Liberation Sans' unless field.key?('font')
        field['media'] = [] unless field.key?('media')
        field['rtl'] = false unless field.key?('rtl')
        field['size'] = 20 unless field.key?('size')
        field['sticky'] = false unless field.key?('sticky')
      end

      {
        "css" => @css,
        "did" => deck_id,
        "flds" => @fields,
        "id" => @model_id.to_s,
        "latexPost" => @latex_post,
        "latexPre" => @latex_pre,
        "latexsvg" => false,
        "mod" => timestamp.to_i,
        "name" => @name,
        "req" => req,
        "sortf" => @sort_field_index,
        "tags" => [],
        "tmpls" => @templates,
        "type" => @model_type,
        "usn" => -1,
        "vers" => []
      }
    end

    def inspect
      attrs = %i[model_id name fields templates css model_type]
      pieces = attrs.map { |attr| "#{attr}=#{send(attr).inspect}" }
      "#{self.class.name}(#{pieces.join(', ')})"
    end
  end
end