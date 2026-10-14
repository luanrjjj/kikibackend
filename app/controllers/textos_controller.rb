class TextosController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_texto, only: %i[ show update destroy ]
  wrap_parameters false

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    sort_column = params[:sort_by] || 'id'
    sort_direction = params[:direction] || 'desc'

    # Whitelist allowed columns for sorting (sem "texto": ordenar pelo conteúdo é caro demais)
    allowed_columns = ['id', 'prova_id', 'concurso_id', 'created_at']
    sort_column = 'id' unless allowed_columns.include?(sort_column)
    sort_direction = 'desc' unless ['asc', 'desc'].include?(sort_direction)

    @textos = Texto.all
    @textos = apply_search(@textos, params[:search]) if params[:search].present?

    # COUNT(*) em textos é caro; guarda por alguns minutos por consulta
    count_key = "admin/textos/count/#{Digest::SHA256.hexdigest(@textos.to_sql)}"
    total_count = Rails.cache.fetch(count_key, expires_in: 10.minutes) { @textos.count }
    @textos = @textos.order("textos.#{sort_column} #{sort_direction}")
    @textos = @textos.order(id: :desc) unless sort_column == 'id' # desempate estável para a paginação
                     .offset((page - 1) * per_page)
                     .limit(per_page)

    render json: {
      data: @textos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @texto
  end

  def all
    render json: Texto.select(:id, :texto).order(id: :desc)
  end

  def create
    @texto = Texto.new(texto_params)

    if @texto.save
      render json: @texto, status: :created
    else
      render json: { message: @texto.errors.full_messages.join(', '), errors: @texto.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @texto.update(texto_params)
      render json: @texto
    else
      render json: { message: @texto.errors.full_messages.join(', '), errors: @texto.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @texto.destroy!
  end

  IMAGEM_TIPOS = %w[image/png image/jpeg image/gif image/webp image/svg+xml].freeze
  IMAGEM_MAX_BYTES = 10.megabytes

  # POST /textos/upload_imagem (multipart: file, texto_id opcional)
  # Envia a imagem para o Spaces em question_images/ e devolve a URL pública.
  # Não grava no texto: o modal coloca a URL em imagem_texto e salva junto
  # com o restante do formulário.
  def upload_imagem
    file = params[:file] || params[:imagem]
    return render json: { error: "Nenhum arquivo enviado." }, status: :bad_request if file.blank?

    unless IMAGEM_TIPOS.include?(file.content_type)
      return render json: { error: "Formato não suportado. Envie PNG, JPG, GIF, WEBP ou SVG." }, status: :unprocessable_entity
    end
    if file.size > IMAGEM_MAX_BYTES
      return render json: { error: "Imagem maior que 10 MB." }, status: :unprocessable_entity
    end

    ext = File.extname(file.original_filename.to_s).downcase.presence || ".#{file.content_type.split('/').last.sub('svg+xml', 'svg')}"
    prefixo = params[:texto_id].present? ? "texto_#{params[:texto_id].to_i}" : "texto"
    key = "question_images/#{prefixo}_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(4)}#{ext}"

    url = SpacesService.upload_file(key, file)
    render json: { url: url, key: key }
  rescue StandardError => e
    Rails.logger.error "TextosController#upload_imagem Error: #{e.message}"
    render json: { error: "Erro ao enviar a imagem: #{e.message}" }, status: :internal_server_error
  end

  private
    # Busca SÓ por id do texto e por concurso (id ou nome). Nunca pelo conteúdo
    # do texto: ILIKE em textos.texto faz full scan na tabela e derruba o banco.
    #   "123" / "#123 456" -> textos 123/456 ou textos dos concursos 123/456
    #   "TCE SC 2024"      -> textos de concursos cujo nome contém "TCE", "SC" e "2024"
    def apply_search(scope, search)
      termos = search.to_s.strip.split(/\s+/).reject(&:blank?)
      return scope if termos.empty?

      if termos.all? { |t| t.delete('#').match?(/\A\d+\z/) }
        ids = termos.map { |t| t.delete('#').to_i }
        return scope.where("textos.id IN (:ids) OR textos.concurso_id IN (:ids)", ids: ids)
      end

      concursos = Concurso.all
      termos.each { |t| concursos = concursos.where("concursos.nome ILIKE ?", "%#{Concurso.sanitize_sql_like(t)}%") }
      scope.where(concurso_id: concursos.select(:id))
    end

    def set_texto
      @texto = Texto.find(params[:id])
    end

    def texto_params
      params.permit(:texto, :prova_id, :concurso_id, :imagem_texto)
    end
end
