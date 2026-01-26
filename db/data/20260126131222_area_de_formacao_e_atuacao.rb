# frozen_string_literal: true

class AreaDeFormacaoEAtuacao < ActiveRecord::Migration[7.1]
  class AreaDeFormacao < ApplicationRecord
    self.table_name = 'area_de_formacaos'
  end

  class AreaDeAtuacao < ApplicationRecord
    self.table_name = 'area_de_atuacaos'
  end

  def up
    file = File.read(Rails.root.join('db', 'json_seeds', 'areas_concursos.json'))
    data = JSON.parse(file)

    data['areas_de_formacao'].each do |area|
      AreaDeFormacao.create(nome: area['nome'])
    end

    data['areas_de_atuacao'].each do |area|
      AreaDeAtuacao.create(nome: area['nome'])
    end
  end

  def down
    AreaDeFormacao.delete_all
    AreaDeAtuacao.delete_all
  end
end