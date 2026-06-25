require 'json'

class PopulateOrgaosEsfera < SeedMigration::Migration
  def up
    json_path = Rails.root.join('db', 'json_seeds', 'concursos_tec_concursos.json')
    return unless File.exist?(json_path)

    file_content = File.read(json_path)
    concursos_data = JSON.parse(file_content)

    concursos_data.each do |data|
      orgao_name = data['orgao']
      regiao = data['regiao']
      next if orgao_name.blank? || regiao.blank?

      # Map regiao to esfera
      esfera_val = case regiao.to_s.downcase
                   when 'municipal' then 'municipal'
                   when 'estadual' then 'estadual'
                   when 'federal' then 'federal'
                   else nil
                   end
      next unless esfera_val

      # Find Orgao and update its esfera
      orgao = Orgao.find_by('nome ILIKE ?', orgao_name)
      orgao ||= Orgao.find_by('nome ILIKE ?', "%#{orgao_name}%")
      
      if orgao && orgao.esfera.nil?
        orgao.update_columns(esfera: esfera_val)
      end
    end
    
    puts "Populated esfera values for Orgaos successfully!"
  end

  def down
    Orgao.update_all(esfera: nil)
  end
end
