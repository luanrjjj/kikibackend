require 'json'

class OrgaosSeed < SeedMigration::Migration
  def up
    json_path = Rails.root.join('db', 'json_seeds', 'orgaos_tec_concursos.json')
    return unless File.exist?(json_path)

    file_content = File.read(json_path)
    orgaos_data = JSON.parse(file_content)

    orgao_model = Class.new(ActiveRecord::Base) { self.table_name = 'orgaos' }

    orgaos_data.each do |data|
      orgao_model.find_or_create_by!(nome: data['nome'])
    end
  end

  def down
    orgao_model = Class.new(ActiveRecord::Base) { self.table_name = 'orgaos' }
    orgao_model.delete_all
  end
end
