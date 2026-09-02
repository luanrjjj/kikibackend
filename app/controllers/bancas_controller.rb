class BancasController < ApplicationController
  before_action :set_banca, only: %i[ show update destroy upload_logo ]
  before_action :authenticate_admin!, only: %i[ all create update destroy upload_logo ]
  skip_before_action :authenticate_user!, only: %i[ show questoes_count filters ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @bancas = Banca.all
    
    if params[:search].present?
      @bancas = @bancas.where("nome ILIKE ? OR sigla ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    total_count = @bancas.count
    @bancas = @bancas.select(
      "bancas.*",
      "(SELECT COUNT(*) FROM concursos WHERE concursos.banca_id = bancas.id) AS concursos_count",
      "(SELECT COUNT(*) FROM provas WHERE provas.banca_id = bancas.id) AS provas_count"
    ).order(Arel.sql("COALESCE(bancas.total_concursos, 0) DESC, bancas.id ASC"))
     .offset((page - 1) * per_page)
     .limit(per_page)

    render json: {
      data: @bancas.as_json(methods: [:concursos_count, :provas_count]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  rescue StandardError => e
    Rails.logger.error "BancasController#index Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    render json: { error: "Erro ao buscar bancas", message: e.message }, status: :internal_server_error
  end

  def all
    render json: Banca.select(:id, :nome, :sigla).order_by_priority.order(:nome)
  rescue StandardError => e
    Rails.logger.error "BancasController#all Error: #{e.message}"
    render json: { error: "Erro ao buscar todas as bancas" }, status: :internal_server_error
  end

  def filters
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 100).to_i, 1].max

    scope = Banca.order_by_priority.order(:nome)
    scope = scope.where('nome ILIKE ? OR sigla ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    total_count = scope.count
    paged_scope = scope.offset((page - 1) * per_page).limit(per_page)
    
    results = paged_scope.pluck(:id, :nome, :sigla).map { |id, nome, sigla| { id: id, nome: nome, sigla: sigla } }

    render json: {
      data: results,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        next_page: page < (total_count.to_f / per_page).ceil ? page + 1 : nil
      }
    }
  rescue StandardError => e
    Rails.logger.error "BancasController#filters Error: #{e.message}"
    render json: { error: "Erro ao filtrar bancas" }, status: :internal_server_error
  end

  def questoes_count
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    search = params[:search].to_s.strip
    
    # Use a version from global config to allow manual/job-based invalidation
    version = ConfigGlobalApolo.get('bancas_questoes_count_version', 'v2')
    cache_key = "bancas/questoes_count/#{version}/page_#{page}/per_#{per_page}/search_#{search.parameterize}"

    result = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      # Strategy: Use denormalized columns for O(1) performance
      base_query = Banca.all

      if search.present?
        base_query = base_query.where('nome ILIKE ?', "%#{search}%")
      end

      total_count = base_query.count

      # Order and select specific columns for the results
      bancas = base_query.select(:id, :nome, :logo, :questaos_count, :com_gabarito_count)
                        .order(questaos_count: :desc)
                        .offset((page - 1) * per_page)
                        .limit(per_page)
      {
        data: bancas.map { |b| 
          { 
            id: b.id, 
            nome: b.nome, 
            logo: b.logo,
            total_questoes: b.questaos_count || 0,
            com_gabarito: b.com_gabarito_count || 0
          } 
        },
        meta: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    end

    render json: result
  rescue StandardError => e
    Rails.logger.error "BancasController#questoes_count Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    render json: { error: "Erro ao buscar contagem de questões", message: e.message }, status: :internal_server_error
  end
  def show
    concursos_list = @banca.concursos
                           .includes(:orgao, :provas)
                           .order(Arel.sql("COALESCE(concursos.inscricoes_ate, concursos.created_at) DESC"))

    concursos_por_ano = Hash.new(0)
    concursos_data = concursos_list.map do |c|
      ano = c.provas.map(&:ano).compact.first ||
            c.inscricoes_ate&.year ||
            c.nome[/\b(19\d\d|20\d\d)\b/]&.to_i ||
            c.created_at&.year

      concursos_por_ano[ano] += 1 if ano

      {
        id: c.id,
        nome: c.nome,
        estagio: c.estagio,
        inscricoes_ate: c.inscricoes_ate,
        edital_nome: c.edital_nome,
        edital_url: c.edital_url,
        pdf_folder_url: c.pdf_folder_url,
        ano: ano,
        orgao: c.orgao ? {
          id: c.orgao.id,
          nome: c.orgao.nome,
          sigla: c.orgao.sigla,
          esfera: c.orgao.esfera,
          logo_url: c.orgao.logo_url
        } : nil,
        provas: c.provas.map { |p| { id: p.id, nome: p.nome, ano: p.ano } },
        provas_count: c.provas.size
      }
    end

    chart_data = concursos_por_ano.sort_by { |year, _| year }.map do |year, count|
      { ano: year.to_s, count: count }
    end

    total_provas = @banca.provas.count
    total_concursos = concursos_list.size

    render json: {
      banca: {
        id: @banca.id,
        nome: @banca.nome,
        sigla: @banca.sigla,
        logo: @banca.logo,
        total_concursos: @banca.total_concursos || total_concursos,
        questaos_count: @banca.questaos_count || 0,
        com_gabarito_count: @banca.com_gabarito_count || 0
      },
      stats: {
        total_concursos: total_concursos,
        total_provas: total_provas,
        total_questoes: @banca.questaos_count || 0,
        com_gabarito: @banca.com_gabarito_count || 0,
        anos_cobertos: chart_data.map { |d| d[:ano] }
      },
      concursos_por_ano: chart_data,
      ultimos_concursos: concursos_data.first(8)
    }
  rescue StandardError => e
    Rails.logger.error "BancasController#show Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    render json: { error: "Erro ao buscar detalhes da banca", message: e.message }, status: :internal_server_error
  end

  def create
    @banca = Banca.new(banca_params)

    if @banca.save
      render json: @banca, status: :created, location: @banca
    else
      render_validation_errors(@banca, "Erro ao criar banca")
    end
  end

  def update
    if @banca.update(banca_params)
      render json: @banca
    else
      render_validation_errors(@banca, "Erro ao atualizar banca")
    end
  end

  def destroy
    @banca.destroy!
  end

  def upload_logo
    file = params[:logo] || params[:file]
    if file.blank?
      render json: { error: "Nenhum arquivo enviado." }, status: :bad_request
      return
    end

    ext = File.extname(file.original_filename).downcase
    ext = '.png' if ext.blank?
    sanitized_nome = @banca ? (@banca.sigla.presence || @banca.nome).to_s.parameterize : "banca_#{Time.current.to_i}"
    key = "bancas_logos/#{sanitized_nome}_#{SecureRandom.hex(4)}#{ext}"

    begin
      url = SpacesService.upload_file(key, file)
      @banca.update!(logo: url) if @banca
      render json: { logo: url, banca: @banca }
    rescue StandardError => e
      Rails.logger.error "BancasController#upload_logo Error: #{e.message}"
      render json: { error: "Erro ao fazer upload da logo: #{e.message}" }, status: :internal_server_error
    end
  end

  private
    def set_banca
      @banca = Banca.find(params[:id]) if params[:id].present?
    end

    def banca_params
      params.require(:banca).permit(:nome, :sigla, :logo, :total_concursos)
    end
end