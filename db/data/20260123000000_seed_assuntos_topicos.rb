require 'json'

class SeedAssuntosTopicos < SeedMigration::Migration
  def up
    json_path = Rails.root.join('db', 'json_seeds', 'all_assuntos.json')
    return unless File.exist?(json_path)

    file_content = File.read(json_path)
    data = JSON.parse(file_content)

    data.each do |item|
      disciplina_nome = item['disciplina']
      assuntos = item['assuntos']

      next unless assuntos.present?
      item['assuntos'].each do |assunto_data|
        assunto_nome = assunto_data['nome'] || assunto_data['name']
        topicos = assunto_data['topicos']


        next unless assunto_nome.present?

        # Try to find discipline
        disciplina = nil
        if disciplina_nome.present?
          disciplina = Disciplina.where('nome ILIKE ?', disciplina_nome).first
          disciplina ||= Disciplina.where('nome ILIKE ?', "%#{disciplina_nome}%").first
        end

        assunto = nil
        if disciplina
          assunto = Assunto.find_or_create_by!(nome: assunto_nome, disciplina: disciplina)
        else
          # Try to find assunto by name if discipline not provided or found
          assunto = Assunto.where('nome ILIKE ?', assunto_nome).first
        end

        next unless assunto

        # Now seed topicos
        if topicos.is_a?(Array)
          topicos.each do |topico_data|
            topico_nome = topico_data.is_a?(Hash) ? (topico_data['nome'] || topico_data['name']) : topico_data.to_s
            next unless topico_nome.present?

            Topico.find_or_create_by!(nome: topico_nome, assunto: assunto) do |t|
              t.disciplina = assunto.disciplina
            end
        end
        end
      end
    end
  end

  def down
    Topico.delete_all
  end
end