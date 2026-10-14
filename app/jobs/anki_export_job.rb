# Gera o .apkg de uma exportação do Anki fora do ciclo da requisição.
# O frontend cria a exportação (POST /anki/exports), acompanha o status
# (GET /anki/exports/:id) e baixa o arquivo (GET /anki/exports/:id/download).
class AnkiExportJob < ApplicationJob
  queue_as :default

  def perform(export_id)
    export = Export.find_by(id: export_id)
    return if export.nil? || export.concluido?

    export.update!(status: 'processando', erro: nil)

    payload = export.payload || {}
    questoes = payload['questoes'] || []
    titulo = export.titulo.presence || payload['title']

    file_path = Rails.root.join('tmp', "anki_export_#{export.id}_#{SecureRandom.hex(4)}.apkg")
    AnkiDeckBuilder.write(questoes, titulo, file_path)

    key = "anki_exports/user_#{export.user_id}/#{export.id}_#{SecureRandom.hex(8)}.apkg"
    File.open(file_path, 'rb') do |file|
      SpacesService.upload_file(key, file, acl: 'private', content_type: 'application/apkg')
    end

    export.update!(status: 'concluido', arquivo_key: key, payload: nil, concluido_em: Time.current)
  rescue StandardError => e
    Rails.logger.error "AnkiExportJob(#{export_id}) falhou: #{e.class}: #{e.message}"
    export&.update_columns(status: 'erro', erro: e.message.to_s.truncate(500), updated_at: Time.current)
  ensure
    File.delete(file_path) if defined?(file_path) && file_path && File.exist?(file_path)
  end
end
