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

    id_counter = 500

    provas_list.each do |item|
      orgao_nome = item['orgao']
      banca_nome = item['banca']
      ano = item['ano'].to_i
      nome_prova = item['nome_prova']
      puts("orgao", orgao_nome)
      puts("banca", banca_nome)
      puts("ano", ano)
      puts("nome_prova", nome_prova)


      next unless orgao_nome.present? && banca_nome.present? && ano > 0 && nome_prova.present?

      orgao = Orgao.where('nome ILIKE ?', orgao_nome).first
      banca = Banca.where('nome ILIKE ?', banca_nome).first
      banca ||= Banca.where('sigla ILIKE ?', banca_nome).first

      # next unless orgao && banca

      prova = Prova.where(nome: nome_prova, orgao: orgao, banca: banca, ano: ano).first
      puts("prova", prova.inspect)
      puts("prova_id", prova&.id)
      puts("prova_nome", prova&.nome)

      next unless prova

      questoes = item['questoes']
      # next unless questoes.is_a?(Array)
      # puts("dsaudhasudhusadhsuahdau", questoes)
      questoes.each do |q_data|
        enunciado = q_data['enunciation']
        alternativas = q_data['options']
        support_text = q_data['support_text']
        next unless enunciado.present?

        disciplina_nome = q_data['breadcrumbs'][0]
        assunto_nome = q_data['breadcrumbs'][-1]
        referencia_id = q_data['id']
        numero_questao = q_data['numero_questao']

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

        texto_obj = nil
        if support_text.present?
          texto_obj = Texto.find_or_create_by(texto: support_text, prova_id: prova.id, concurso_id: prova.concurso_id)
        end

        questao = Questao.find_or_initialize_by(enunciado: enunciado, prova: prova)

        if questao.real_id.blank?
          suffix = (0...2).map { (('0'..'9').to_a + ('A'..'Z').to_a).sample }.join
          questao.real_id = "R#{id_counter}#{suffix}"
          id_counter += 1
        end

        questao.discursiva = false
        questao.ano = ano
        questao.concurso = prova.concurso
        questao.assunto = assunto
        questao.disciplina = disciplina
        questao.texto_id = texto_obj&.id
        questao.alternativas = alternativas
        questao.sistema_ref_id = referencia_id
        questao.numero_questao = numero_questao
        questao.save!
      end
    end
    puts "Import finished!"
  end

  def down
    Questao.delete_all
  end
end
