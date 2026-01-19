require 'json'

class QuestoesQconcursos < SeedMigration::Migration
  def up
    file_path = Rails.root.join('db', 'json_seeds', 'combined_provas.json')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      return
    end

    puts "Importing Questoes from #{file_path}..."

    json_data = File.read(file_path)
    provas_list = JSON.parse(json_data)

    provas_list.each do |item|
      orgao_nome = item['orgao']
      banca_nome = item['banca']
      ano = item['ano'].to_i
      nome_prova = item['nome_prova']
      texto = item['support_text']

      next unless orgao_nome.present? && banca_nome.present? && ano > 0 && nome_prova.present?

      orgao = Orgao.where('nome ILIKE ?', orgao_nome).first
      banca = Banca.where('nome ILIKE ?', banca_nome).first
      banca ||= Banca.where('sigla ILIKE ?', banca_nome).first

      # next unless orgao && banca

      prova = Prova.where(nome: nome_prova, orgao: orgao, banca: banca, ano: ano).first
      # next unless prova

      questoes = item['questoes']
      # next unless questoes.is_a?(Array)
      # puts("dsaudhasudhusadhsuahdau", questoes)
      questoes.each do |q_data|
        enunciado = q_data['enunciation']
        alternativas = q_data['options']
        next unless enunciado.present?

        disciplina_nome = q_data['breadcrumbs'][0]
        assunto_nome = q_data['breadcrumbs'][-1]

        disciplina = nil
        if disciplina_nome.present?
          disciplina = Disciplina.where('nome ILIKE ?', disciplina_nome).first
        end

        assunto = nil
        if assunto_nome.present?
          if disciplina
            assunto = Assunto.where('nome ILIKE ?', assunto_nome).where(disciplina: disciplina).first
          else
            assunto = Assunto.where('nome ILIKE ?', assunto_nome).first
            disciplina ||= assunto.disciplina if assunto
          end
        end
        puts("disciplina", disciplina)
        puts("assunto", assunto)

        questao = Questao.find_or_initialize_by(enunciado: enunciado, prova: prova)
        questao.discursiva = false
        questao.ano = ano
        questao.concurso = prova.concurso
        questao.assunto = assunto
        questao.disciplina = disciplina
        questao.texto = texto
        questao.alternativas = alternativas
        questao.save!
      end
    end
    puts "Import finished!"
  end

  def down
    Questao.delete_all
  end
end
