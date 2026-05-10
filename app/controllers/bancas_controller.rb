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

    cache_key = "bancas/questoes_count/page_#{page}/per_#{per_page}/search_#{search.parameterize}"

    result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      query = Banca.joins(provas: :questaos)
                   .group('bancas.id', 'bancas.nome', 'bancas.logo')
                   .select('bancas.id, bancas.nome, bancas.logo,
                           count(questaos.id) as total_questoes,
                           count(CASE WHEN questaos.correta IS NOT NULL AND questaos.correta != \'\' THEN 1 END) as com_gabarito')

      if search.present?
        query = query.where('bancas.nome ILIKE ?', "%#{search}%")
      end

      total_count = if search.present?
                      Banca.joins(provas: :questaos).where('bancas.nome ILIKE ?', "%#{search}%").distinct.count('bancas.id')
                    else
                      Banca.joins(provas: :questaos).distinct.count('bancas.id')
                    end

      counts = query.order('total_questoes DESC').offset((page - 1) * per_page).limit(per_page)

      {
        data: counts.map { |b|
          {
            id: b.id,
            nome: b.nome,
            logo: b.logo,
            total_questoes: b.total_questoes,
            com_gabarito: b.com_gabarito
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
    render json: { error: "Erro ao calcular contagem de questões por banca", message: e.message }, status: :internal_server_error
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