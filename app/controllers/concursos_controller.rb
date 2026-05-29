class ConcursosController < ApplicationController
  before_action :set_concurso, only: %i[ show update destroy ]
  skip_before_action :authenticate_user!, only: [:public_index]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @concursos = Concurso.all
    
    if params[:search].present?
      @concursos = @concursos.where("nome ILIKE ?", "%#{params[:search]}%")
    end

    total_count = @concursos.count
    @concursos = @concursos.includes(:banca, :orgao)
                         .order(created_at: :desc)
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @concursos.as_json(include: [:banca, :orgao]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def public_index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 10).to_i, 1].max

    @concursos = Concurso.all

    if params[:nome].present?
      @concursos = @concursos.where("concursos.nome ILIKE ?", "%#{params[:nome]}%")
    end

    if params[:banca_id].present?
      banca_ids = params[:banca_id].is_a?(Array) ? params[:banca_id] : [params[:banca_id]]
      @concursos = @concursos.where(banca_id: banca_ids)
    end

    if params[:ano].present?
      anos = params[:ano].is_a?(Array) ? params[:ano] : [params[:ano]]
      @concursos = @concursos.where(id: Concurso.joins(:provas).where(provas: { ano: anos }).select(:id))
    end

    total_count = @concursos.count
    @concursos = @concursos.includes(:banca, :orgao, :provas)
                         .order(Arel.sql("CASE WHEN inscricoes_ate >= CURRENT_DATE THEN 0 ELSE 1 END, CASE WHEN inscricoes_ate >= CURRENT_DATE THEN inscricoes_ate END ASC, inscricoes_ate DESC NULLS LAST"))
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @concursos.as_json(include: {
        banca: { only: [:id, :nome, :sigla, :logo] },
        orgao: { except: [:created_at, :updated_at] },
        provas: { only: [:id, :nome, :ano] }
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @concurso
  end

  def stats
    has_filters = params[:search].present?

    if !has_filters
      cached_stats = Rails.cache.read("admin/stats/concursos/global")
      if cached_stats
        Rails.logger.info "[Cache] Hit admin/stats/concursos/global"
        render json: cached_stats
        return
      else
        Rails.logger.info "[Cache] Miss admin/stats/concursos/global"
      end
    end

    @concursos = Concurso.all

    # Filter by name if search present
    @concursos = @concursos.where("nome ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    total_count = @concursos.count

    # Calculate by_year using provas associated with the concursos
    by_year = Concurso.joins(:provas)
                     .where(id: @concursos.pluck(:id))
                     .group('provas.ano')
                     .distinct
                     .count('concursos.id')
                     .sort.to_h

    render_data = {
      total_count: total_count,
      by_year: by_year,
      updated_at: Time.current
    }

    # Cache global results if no filters were applied
    Rails.cache.write("admin/stats/concursos/global", render_data) if !has_filters

    render json: render_data
  end

  def all
    @concursos = Concurso.select(:id, :nome).order(:nome)
    
    if params[:search].present?
      @concursos = @concursos.where("nome ILIKE ?", "%#{params[:search]}%")
    end

    # If search is present, we limit to 50. If not, we return everything (for backward compatibility if needed)
    # but ideally we should always limit or use pagination for very large sets.
    @concursos = @concursos.limit(50) if params[:search].present?

    render json: @concursos
  end

  def create
    @concurso = Concurso.new(concurso_params)

    if @concurso.save
      render json: @concurso, status: :created, location: @concurso
    else
      render json: @concurso.errors, status: :unprocessable_entity
    end
  end

  def update
    if @concurso.update(concurso_params)
      render json: @concurso
    else
      render json: @concurso.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @concurso.destroy!
  end

  # DELETE /concursos/destroy_by_name?nome=XXX
  def destroy_by_name
    if params[:nome].blank?
      render json: { error: "Nome é obrigatório" }, status: :bad_request
      return
    end

    @concursos = Concurso.where(nome: params[:nome])
    count = @concursos.count

    if count == 0
      render json: { message: "Nenhum concurso encontrado com o nome: #{params[:nome]}" }, status: :not_found
      return
    end

    @concursos.destroy_all

    render json: {
      message: "Sucesso ao deletar concursos",
      count: count,
      nome: params[:nome]
    }, status: :ok
  end

  private
    def set_concurso
      @concurso = Concurso.find(params[:id])
    end

    def concurso_params
      params.require(:concurso).permit(:nome, :inscricoes_ate, :edital_nome, :banca_id, :orgao_id, :cargos, :edital_url, :estagio)
    end
end
