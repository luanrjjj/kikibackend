class GuiasController < ApplicationController
  before_action :set_guia, only: %i[ show update destroy ]
  skip_before_action :authenticate_user!, only: [:public_index]

  # GET /guias (Admin/Private list)
  def index
    @guias = Guia.includes(concurso: :orgao).includes(:filtros).all
    render json: @guias.as_json(include_associations)
  end

  # GET /guias/public_index
  def public_index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 10).to_i, 1].max

    @guias = Guia.all

    if params[:nome].present?
      @guias = @guias.where("guias.nome ILIKE ?", "%#{params[:nome]}%")
    end

    if params[:concurso_id].present?
      @guias = @guias.where(concurso_id: params[:concurso_id])
    end

    total_count = @guias.count
    @guias = @guias.includes(concurso: :orgao).includes(:filtros)
                   .order(created_at: :desc)
                   .offset((page - 1) * per_page)
                   .limit(per_page)

    render json: {
      data: @guias.as_json(include_associations),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /guias/1
  def show
    render json: @guia.as_json(include_associations)
  end

  # POST /guias
  def create
    @guia = Guia.new(guia_params)

    if @guia.save
      update_filtros if params.key?(:filtro_ids)
      render json: @guia.as_json(include_associations), status: :created
    else
      render json: @guia.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /guias/1
  def update
    if @guia.update(guia_params)
      update_filtros if params.key?(:filtro_ids)
      render json: @guia.as_json(include_associations)
    else
      render json: @guia.errors, status: :unprocessable_entity
    end
  end

  # DELETE /guias/1
  def destroy
    @guia.destroy!
  end

  private

  def set_guia
    @guia = Guia.find(params[:id])
  end

  def guia_params
    params.require(:guia).permit(:nome, :concurso_id)
  end

  def update_filtros
    ids = Array(params[:filtro_ids]).map(&:to_i).reject(&:zero?)
    @guia.filtro_ids = ids
  end

  def include_associations
    {
      include: {
        concurso: {
          only: [:id, :nome, :inscricoes_ate, :edital_url],
          include: { orgao: { only: [:id, :nome, :sigla, :logo_url] } }
        },
        filtros: { only: [:id, :nome_do_filtro, :filtro] },
        guia_filtros: {
          include: {
            cargo_guia: { only: [:id, :nome_do_cargo] }
          }
        }
      }
    }
  end
end
