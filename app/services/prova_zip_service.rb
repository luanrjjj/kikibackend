require 'zip'
require 'digest'

# Gera (ou reaproveita) o .zip da pasta da prova no Spaces (pdfs_folder_url).
#
# pdfs_folder_url aponta para uma "pasta" no Spaces, por exemplo
#   https://arquivos.apoloconcursos.com.br/concursos_pdfs/Concurso_X_2026/Cargo/
# O navegador não consegue baixar uma pasta, então o zip é montado aqui com
# todos os arquivos dela e guardado em downloads/provas/. O nome do zip leva
# um resumo das chaves/ETags dos arquivos: enquanto a pasta não mudar, o mesmo
# zip é reaproveitado; se um arquivo mudar, um zip novo é gerado.
class ProvaZipService
  class PastaVazia < StandardError; end
  class PastaInvalida < StandardError; end

  MAX_ARQUIVOS = 200
  MAX_BYTES = 500.megabytes

  def self.url_do_zip(prova)
    new(prova).url_do_zip
  end

  def initialize(prova)
    @prova = prova
  end

  # URL pública (CDN) do zip da pasta, gerando-o se ainda não existir.
  def url_do_zip
    objetos = listar_objetos
    raise PastaVazia, 'A pasta da prova não tem arquivos.' if objetos.empty?
    if objetos.size > MAX_ARQUIVOS || objetos.sum(&:size) > MAX_BYTES
      raise PastaInvalida, 'A pasta da prova é grande demais para gerar o zip.'
    end

    assinatura = Digest::SHA1.hexdigest(objetos.map { |o| "#{o.key}:#{o.etag}:#{o.size}" }.sort.join('|'))[0, 12]
    zip_key = "downloads/provas/prova_#{@prova.id}_#{assinatura}.zip"

    gerar_zip(objetos, zip_key) unless existe?(zip_key)
    SpacesService.cdn_url(zip_key)
  end

  # "concursos_pdfs/Concurso_X/Cargo/" a partir da URL (CDN ou endpoint do Spaces)
  def prefixo
    url = @prova.pdfs_folder_url.to_s.strip
    raise PastaInvalida, 'A prova não tem pasta de PDFs.' if url.blank?

    # Tira esquema e host e decodifica %XX uma única vez (a URL pode vir com
    # espaços/acentos crus ou já codificada). "+" é literal em chave do S3.
    caminho = url.sub(%r{\Ahttps?://[^/]+}i, '').split(/[?#]/).first.to_s
    caminho = URI.decode_www_form_component(caminho.gsub('+', '%2B')).sub(%r{\A/+}, '')
    # Se o host for o endpoint do Spaces com o bucket no caminho, remove o bucket
    caminho = caminho.sub(%r{\A#{Regexp.escape(SpacesService.bucket)}/}, '')
    # Apontando para um arquivo (ex.: .../prova.pdf): usa a pasta dele
    caminho = File.dirname(caminho) + '/' if File.extname(caminho).present? && !caminho.end_with?('/')
    caminho = "#{caminho}/" unless caminho.end_with?('/')
    raise PastaInvalida, 'Caminho da pasta de PDFs inválido.' if caminho == '/' || caminho.blank?

    caminho
  rescue ArgumentError
    raise PastaInvalida, 'URL da pasta de PDFs inválida.'
  end

  private

  def listar_objetos
    objetos = []
    token = nil
    loop do
      resp = SpacesService.client.list_objects_v2(bucket: SpacesService.bucket, prefix: prefixo, continuation_token: token)
      objetos.concat(resp.contents.reject { |o| o.key.end_with?('/') || o.size.to_i.zero? })
      break unless resp.is_truncated

      token = resp.next_continuation_token
    end
    objetos
  end

  def existe?(key)
    SpacesService.client.head_object(bucket: SpacesService.bucket, key: key)
    true
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    false
  end

  def gerar_zip(objetos, zip_key)
    tmp = Tempfile.new(["prova_#{@prova.id}", '.zip'], binmode: true)
    usados = Hash.new(0)

    Zip::OutputStream.open(tmp.path) do |zos|
      objetos.each do |obj|
        relativo = obj.key.delete_prefix(prefixo)
        nome = relativo.presence || File.basename(obj.key)
        usados[nome] += 1
        nome = "#{File.basename(nome, '.*')}_#{usados[nome]}#{File.extname(nome)}" if usados[nome] > 1

        zos.put_next_entry(nome)
        SpacesService.client.get_object(bucket: SpacesService.bucket, key: obj.key) do |chunk|
          zos.write(chunk)
        end
      end
    end

    File.open(tmp.path, 'rb') do |file|
      SpacesService.upload_file(zip_key, file, acl: 'public-read', content_type: 'application/zip')
    end
  ensure
    tmp&.close!
  end
end
