class GuiasController < ApplicationController
  before_action :set_guia, only: %i[ show update destroy ]

  # GET /guias
  def index
    @guias = Guia.includes(:concurso, :filtros).all
    render json: @guias.as_json(include: { concurso: { only: [:id, :nome] }, filtros: { only: [:id, :nome_do_filtro] } })
  end

  # GET /guias/1
  def show
    render json: @guia.as_json(include: { filtros: { only: [:id, :nome_do_filtro] } })
  end

  # POST /guias
  def create
    @guia = Guia.new(guia_params)

    if @guia.save
      update_filtros if params[:filtro_ids].present?
      render json: @guia, status: :created
    else
      render json: @guia.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /guias/1
  def update
    if @guia.update(guia_params)
      update_filtros if params[:filtro_ids].present?
      render json: @guia
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
    @guia.filtro_ids = params[:filtro_ids]
  end
end
