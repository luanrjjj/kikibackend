require 'json'

class ProvasQconcursos < SeedMigration::Migration
  def up
    file_path = Rails.root.join('db', 'json_seeds', 'combined_provas.json')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      return
    end

    puts "Importing Provas from #{file_path}..."

    json_data = File.read(file_path)
    provas_list = JSON.parse(json_data)

    provas_list.each do |item|
      # 1. Match or Create Orgao
      orgao_nome = item['orgao']
      next unless orgao_nome.present?

      orgao = Orgao.where('nome ILIKE ?', orgao_nome).first
      orgao ||= Orgao.create!(nome: orgao_nome)

      # 2. Match or Create Banca
      banca_nome = item['banca']
      next unless banca_nome.present?

      banca = Banca.where('nome ILIKE ?', banca_nome).first
      banca ||= Banca.where('sigla ILIKE ?', banca_nome).first
      banca ||= Banca.create!(nome: banca_nome, sigla: banca_nome)

      # 3. Match or Create Concurso
      ano = item['ano'].to_i
      next unless ano > 0

      # Try to find existing concurso by orgao, banca and year
      concurso = Concurso.where(orgao: orgao, banca: banca)
                         .where('EXTRACT(YEAR FROM inscricoes_ate) = ?', ano)
                         .first

      unless concurso
        # Create a generic concurso if not found
        concurso = Concurso.create!(
          nome: "Concurso #{orgao.nome} #{ano}",
          orgao: orgao,
          banca: banca,
          inscricoes_ate: Date.new(ano, 1, 1)
        )
      end

      # 4. Create Prova
      Prova.find_or_create_by!(nome: item['nome_prova'], orgao: orgao, banca: banca, concurso: concurso, ano: ano)
    end
    puts "Import finished!"
  end

  def down
    Prova.delete_all
  end
end
