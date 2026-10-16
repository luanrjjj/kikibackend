require 'zip'
require 'stringio'

# Monta o .zip com todos os arquivos da pasta de uma prova no Spaces.
#
# A pasta vem do próprio banco (provas.pdfs_folder_url ou, na falta dela, a
# pasta do provas.prova_url) — nunca de um parâmetro da requisição. Mesmo assim
# só são aceitos prefixos conhecidos, com ao menos uma subpasta, para que um
# dado errado no banco não gere um zip do bucket inteiro.
#
# O zip é montado em memória, por isso há limites de arquivos e de tamanho.
class ProvaZipService
  class Error < StandardError
    attr_reader :status

    def initialize(message, status = :unprocessable_entity)
      super(message)
      @status = status
    end
  end

  Result = Struct.new(:data, :filename, :file_count, keyword_init: true)

  # concursos_pdfs/<pasta>/...  ou  provas_downloads[_N]/<pasta>/...
  PREFIXOS_PERMITIDOS = %r{\A(concursos_pdfs|provas_downloads(_\d+)?)/[^/]+/}
  MAX_ARQUIVOS = 200
  MAX_BYTES = 150 * 1024 * 1024

  def initialize(prova)
    @prova = prova
  end

  def call
    prefixo = self.class.prefixo_da_prova(@prova)
    raise Error.new('Esta prova não possui arquivos para download.', :not_found) if prefixo.blank?

    objetos = SpacesService.list_objects(prefixo)
    raise Error.new('Nenhum arquivo encontrado para esta prova.', :not_found) if objetos.empty?

    total = objetos.sum { |o| o[:size] }
    if objetos.size > MAX_ARQUIVOS || total > MAX_BYTES
      raise Error.new('Esta prova tem arquivos demais para um único download.', :payload_too_large)
    end

    usados = {}
    buffer = Zip::OutputStream.write_buffer(StringIO.new(String.new)) do |zip|
      objetos.each do |obj|
        nome = self.class.nome_no_zip(obj[:key], prefixo, usados)
        next if nome.nil?

        zip.put_next_entry(nome)
        zip.write(SpacesService.read_object(obj[:key]))
      end
    end

    Result.new(data: buffer.string, filename: nome_do_zip, file_count: usados.size)
  end

  # "concursos_pdfs/Concurso_X/Cargo_Y/" a partir da prova, ou nil se inválido.
  def self.prefixo_da_prova(prova)
    url = prova.pdfs_folder_url.presence
    url ||= prova.prova_url.to_s.sub(/[?#].*\z/, '').sub(%r{[^/]*\z}, '').presence # pasta onde está o prova.pdf
    chave = chave_da_url(url)
    return nil if chave.blank?

    chave += '/' unless chave.end_with?('/')
    return nil unless chave.match?(PREFIXOS_PERMITIDOS)
    return nil if chave.split('/').any? { |parte| parte == '..' || parte == '.' }

    chave
  end

  # Aceita URL do domínio customizado, do Spaces/CDN (host.bucket ou path-style)
  # e devolve só a chave do objeto.
  def self.chave_da_url(url)
    return nil if url.blank?

    caminho = url.to_s.strip.sub(%r{\Ahttps?://[^/]+}, '').sub(/[?#].*\z/, '')
    caminho = CGI.unescapeURIComponent(caminho).sub(%r{\A/+}, '')
    caminho.delete_prefix("#{SpacesService.bucket_name}/")
  end

  # Caminho do arquivo dentro do zip (relativo à pasta da prova), higienizado.
  # Nomes repetidos ganham sufixo; devolve nil para entradas inválidas.
  def self.nome_no_zip(chave, prefixo, usados)
    relativo = chave.delete_prefix(prefixo)
    partes = relativo.split('/').reject(&:blank?).map do |parte|
      ActiveSupport::Inflector.transliterate(parte).gsub(/[^A-Za-z0-9._ -]/, '_')
    end
    return nil if partes.empty? || partes.any? { |p| p == '..' || p == '.' }

    nome = partes.join('/')
    if usados.key?(nome)
      dir = File.dirname(nome)
      dir = nil if dir == '.'
      base = File.basename(nome, '.*')
      ext = File.extname(nome)
      n = 2
      n += 1 while usados.key?([dir, "#{base}_#{n}#{ext}"].compact.join('/'))
      nome = [dir, "#{base}_#{n}#{ext}"].compact.join('/')
    end
    usados[nome] = true
    nome
  end

  private

  def nome_do_zip
    base = [@prova.nome, @prova.ano].compact.join(' ').parameterize
    "#{base.presence || "prova-#{@prova.id}"}.zip"
  end
end
