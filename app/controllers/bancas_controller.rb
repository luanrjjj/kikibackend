class BancasController < ApplicationController
  before_action :set_banca, only: %i[ show update destroy ]
  before_action :authenticate_admin!, only: %i[ all ]
  # skip_before_action :authenticate_user!, only: [:all]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @bancas = Banca.order(total_concursos: :desc).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @bancas,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Banca.count,
        total_pages: (Banca.count.to_f / per_page).ceil
      }
    }
  rescue StandardError => e
    Rails.logger.error "BancasController#index Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    render json: { error: "Erro ao buscar bancas", message: e.message }, status: :internal_server_error
  end

  def all
    render json: Banca.order(:nome)
  rescue StandardError => e
    Rails.logger.error "BancasController#all Error: #{e.message}"
    render json: { error: "Erro ao buscar todas as bancas" }, status: :internal_server_error
  end

  def filters
    scope = Banca.order(:nome)
    scope = scope.where('nome ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    render json: scope.pluck(:id, :nome).map { |id, nome| { id: id, nome: nome } }
  rescue StandardError => e
    Rails.logger.error "BancasController#filters Error: #{e.message}"
    render json: { error: "Erro ao filtrar bancas" }, status: :internal_server_error
  end

  def questoes_count
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    search = params[:search].to_s.strip

    cache_key = "bancas/questoes_count/v2/page_#{page}/per_#{per_page}/search_#{search.parameterize}"

    result = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
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