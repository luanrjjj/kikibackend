require 'aws-sdk-s3'

class SpacesService
  def self.client
    @client ||= Aws::S3::Client.new(
      access_key_id: ENV['SPACES_ACCESS_KEY'],
      secret_access_key: ENV['SPACES_SECRET_KEY'],
      endpoint: ENV['SPACES_ENDPOINT_URL'],
      region: ENV['SPACES_REGION']
    )
  end

  def self.create_folder(folder_name)
    bucket = ENV['SPACES_BUCKET_NAME']
    # S3 folders are just objects with a trailing slash
    key = "concursos_pdfs/#{folder_name}/"

    begin
      client.put_object(bucket: bucket, key: key)
      # Return the "URL" - technically it's a path, but we can provide the full URL if needed
      "#{ENV['SPACES_ENDPOINT']}/#{bucket}/#{key}"
    rescue StandardError => e
      Rails.logger.error "SpacesService#create_folder Error: #{e.message}"
      raise e
    end
  end

  def self.upload_file(key, file)
    bucket = ENV['SPACES_BUCKET_NAME']

    begin
      client.put_object(
        bucket: bucket,
        key: key,
        body: file.read,
        acl: 'public-read',
        content_type: file.content_type
      )
      "#{ENV['SPACES_ENDPOINT']}/#{bucket}/#{key}"
    rescue StandardError => e
      Rails.logger.error "SpacesService#upload_file Error: #{e.message}"
      raise e
    end
  end
end
