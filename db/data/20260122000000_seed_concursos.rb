require 'json'

class SeedConcursos < SeedMigration::Migration
  def up
    json_path = Rails.root.join('db', 'json_seeds', 'concursos_tec_concursos.json')
    return unless File.exist?(json_path)

    file_content = File.read(json_path)
    concursos_data = JSON.parse(file_content)

    concursos_data.each do |data|
      # Find Orgao by its name
      orgao_name = data['orgao']
      orgao = Orgao.where('nome ILIKE ?', orgao_name).first
      orgao ||= Orgao.where('nome ILIKE ?', "%#{orgao_name}%").first

      unless orgao
        puts "Skipping concurso, Orgao not found: #{orgao_name}"
        next
      end

      # Parse the banca name and find it
      banca_str = data['banca']
      banca_name = banca_str.split(' (').first.strip
      banca = Banca.where('nome ILIKE ?', banca_name).first
      banca ||= Banca.where('nome ILIKE ?', "%#{banca_name}%").first

      if !banca
        match = banca_str.match(/\((.*?)\)/)
        banca = Banca.where('sigla ILIKE ?', match[1]).first if match && match[1] != "página do concurso"
      end

      unless banca
        puts "Skipping concurso, Banca not found: #{banca_name}"
        next
      end

      inscricoes_ate = Date.strptime(data['inscricoes_ate'], '%d/%m/%Y') rescue nil
      next unless inscricoes_ate

      concurso_nome = "Concurso #{orgao.nome} #{inscricoes_ate.year}"
      puts "Creating concurso: #{concurso_nome}"
      puts "Orgao: #{orgao.id}"
      puts "Banca: #{banca.id}"


      Concurso.find_or_create_by!(edital_nome: data['edital_nome'], orgao_id: orgao.id, banca_id: banca.id) do |concurso|
        concurso.nome = concurso_nome
        concurso.inscricoes_ate = inscricoes_ate
        concurso.cargos = data['cargos']
      end
    end
  end

  def down
    Concurso.delete_all
  end
end