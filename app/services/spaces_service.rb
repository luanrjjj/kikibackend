require 'aws-sdk-s3'

class SpacesService
  CDN_BASE_URL = (ENV['CDN_SPACES_URL'] || 'https://arquivos.apoloconcursos.com.br').gsub(/\/+$/, '')

  def self.client
    @client ||= Aws::S3::Client.new(
      access_key_id: ENV['SPACES_ACCESS_KEY'] || ENV['SPACES_KEY'],
      secret_access_key: ENV['SPACES_SECRET_KEY'] || ENV['SPACES_SECRET'],
      endpoint: ENV['SPACES_ENDPOINT_URL'] || ENV['SPACES_ENDPOINT'] || 'https://sfo3.digitaloceanspaces.com',
      region: ENV['SPACES_REGION'] || 'sfo3'
    )
  end

  def self.cdn_url(key)
    clean_key = key.to_s.sub(/\A\/+/, '')
    "#{CDN_BASE_URL}/#{clean_key}"
  end

  def self.create_folder(folder_name)
    bucket = ENV['SPACES_BUCKET_NAME'] || ENV['SPACES_BUCKET'] || 'kikiproject'
    # S3 folders are just objects with a trailing slash
    key = "concursos_pdfs/#{folder_name}/"

    begin
      client.put_object(bucket: bucket, key: key)
      cdn_url(key)
    rescue StandardError => e
      Rails.logger.error "SpacesService#create_folder Error: #{e.message}"
      raise e
    end
  end

  def self.upload_file(key, file)
    bucket = ENV['SPACES_BUCKET_NAME'] || ENV['SPACES_BUCKET'] || 'kikiproject'

    begin
      client.put_object(
        bucket: bucket,
        key: key,
        body: file.respond_to?(:read) ? file.read : file,
        acl: 'public-read',
        content_type: file.respond_to?(:content_type) ? file.content_type : 'application/octet-stream'
      )
      cdn_url(key)
    rescue StandardError => e
      Rails.logger.error "SpacesService#upload_file Error: #{e.message}"
      raise e
    end
  end
end
