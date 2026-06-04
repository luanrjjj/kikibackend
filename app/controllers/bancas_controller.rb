class BancasController < ApplicationController
  before_action :set_banca, only: %i[ show update destroy ]
  before_action :authenticate_admin!, only: %i[ all ]
  # skip_before_action :authenticate_user!, only: [:all]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @bancas = Banca.all
    
    if params[:search].present?
      @bancas = @bancas.where("nome ILIKE ? OR sigla ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    total_count = @bancas.count
    @bancas = @bancas.order(total_concursos: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @bancas,
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
    render json: Banca.select(:id, :nome, :sigla).order(:nome)
  rescue StandardError => e
    Rails.logger.error "BancasController#all Error: #{e.message}"
    render json: { error: "Erro ao buscar todas as bancas" }, status: :internal_server_error
  end

  def filters
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 100).to_i, 1].max

    scope = Banca.order(:nome)
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
    render json: @banca
  end

  def create
    @banca = Banca.new(banca_params)

    if @banca.save
      render json: @banca, status: :created, location: @banca
    else
      render json: @banca.errors, status: :unprocessable_entity
    end
  end

  def update
    if @banca.update(banca_params)
      render json: @banca
    else
      render json: @banca.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @banca.destroy!
  end

  private
    def set_banca
      @banca = Banca.find(params[:id])
    end

    def banca_params
      params.require(:banca).permit(:nome, :sigla, :logo, :total_concursos)
    end
end