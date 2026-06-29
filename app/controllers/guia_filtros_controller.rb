class GuiaFiltrosController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_guia_filtro, only: %i[ show update destroy ]

  # GET /guia_filtros
  def index
    @guia_filtros = GuiaFiltro.all
    if params[:guia_id].present?
      @guia_filtros = @guia_filtros.where(guia_id: params[:guia_id])
    end
    if params[:cargo_guia_id].present?
      @guia_filtros = @guia_filtros.where(cargo_guia_id: params[:cargo_guia_id])
    end
    
    # Preload the associated filters and cargo
    @guia_filtros = @guia_filtros.includes(:filtro, :filtro_2, :filtro_3, :cargo_guia)

    render json: @guia_filtros.as_json(
      include: {
        filtro: { only: [:id, :nome_do_filtro, :filtro] },
        filtro_2: { only: [:id, :nome_do_filtro, :filtro] },
        filtro_3: { only: [:id, :nome_do_filtro, :filtro] },
        cargo_guia: { only: [:id, :nome_do_cargo] }
      }
    )
  end

  # GET /guia_filtros/1
  def show
    render json: @guia_filtro.as_json(
      include: {
        filtro: { only: [:id, :nome_do_filtro, :filtro] },
        filtro_2: { only: [:id, :nome_do_filtro, :filtro] },
        filtro_3: { only: [:id, :nome_do_filtro, :filtro] },
        cargo_guia: { only: [:id, :nome_do_cargo] }
      }
    )
  end

  # POST /guia_filtros
  def create
    @guia_filtro = GuiaFiltro.new(guia_filtro_params)

    if @guia_filtro.save
      render json: @guia_filtro.as_json(
        include: {
          filtro: { only: [:id, :nome_do_filtro, :filtro] },
          filtro_2: { only: [:id, :nome_do_filtro, :filtro] },
          filtro_3: { only: [:id, :nome_do_filtro, :filtro] },
          cargo_guia: { only: [:id, :nome_do_cargo] }
        }
      ), status: :created
    else
      render json: @guia_filtro.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /guia_filtros/1
  def update
    if @guia_filtro.update(guia_filtro_params)
      render json: @guia_filtro.as_json(
        include: {
          filtro: { only: [:id, :nome_do_filtro, :filtro] },
          filtro_2: { only: [:id, :nome_do_filtro, :filtro] },
          filtro_3: { only: [:id, :nome_do_filtro, :filtro] },
          cargo_guia: { only: [:id, :nome_do_cargo] }
        }
      )
    else
      render json: @guia_filtro.errors, status: :unprocessable_entity
    end
  end

  # DELETE /guia_filtros/1
  def destroy
    @guia_filtro.destroy!
  end

  private

  def set_guia_filtro
    @guia_filtro = GuiaFiltro.find(params[:id])
  end

  def guia_filtro_params
    params.require(:guia_filtro).permit(:guia_id, :cargo_guia_id, :nome, :filtro_id_1, :filtro_id_2, :filtro_id_3)
  end
end
