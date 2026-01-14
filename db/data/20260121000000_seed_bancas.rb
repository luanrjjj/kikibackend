require 'json'

class SeedBancas < SeedMigration::Migration
  def up
    json_path = Rails.root.join('db', 'json_seeds', 'bancas_tec_concursos.json')
    return unless File.exist?(json_path)

    file_content = File.read(json_path)
    bancas_data = JSON.parse(file_content)

    banca_model = Class.new(ActiveRecord::Base) { self.table_name = 'bancas' }

    bancas_data.each do |data|
      nome = data['nome'] || data['nome']
      sigla = data['sigla']
      total_concursos = data['total_concursos']

      next unless nome.present?

      banca_model.find_or_create_by!(nome: nome) do |b|
        b.sigla = sigla || nome
        b.total_concursos = total_concursos || 0
      end
    end
  end

  def down
    banca_model = Class.new(ActiveRecord::Base) { self.table_name = 'bancas' }
    banca_model.delete_all
  end
end