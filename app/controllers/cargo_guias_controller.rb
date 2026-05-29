class CargoGuiasController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_cargo_guia, only: %i[ show update destroy ]

  # GET /cargo_guias
  def index
    @cargo_guias = CargoGuia.all
    if params[:guia_id].present?
      @cargo_guias = @cargo_guias.joins(:guia_filtros).where(guia_filtros: { guia_id: params[:guia_id] }).distinct
    end
    render json: @cargo_guias.as_json(include: :filtro)
  end

  # GET /cargo_guias/1
  def show
    render json: @cargo_guia.as_json(include: :filtro)
  end

  # POST /cargo_guias
  def create
    @cargo_guia = CargoGuia.new(cargo_guia_params)

    if @cargo_guia.save
      if params[:guia_id].present?
        # Create or update association
        guia_filtro = GuiaFiltro.find_or_initialize_by(guia_id: params[:guia_id], filtro_id: @cargo_guia.filtro_id)
        guia_filtro.cargo_guia_id = @cargo_guia.id
        guia_filtro.save!
      end
      render json: @cargo_guia.as_json(include: :filtro), status: :created
    else
      render json: @cargo_guia.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /cargo_guias/1
  def update
    if @cargo_guia.update(cargo_guia_params)
      # Ensure associated GuiaFiltro records are updated if the filter changed
      GuiaFiltro.where(cargo_guia_id: @cargo_guia.id).update_all(filtro_id: @cargo_guia.filtro_id)
      render json: @cargo_guia.as_json(include: :filtro)
    else
      render json: @cargo_guia.errors, status: :unprocessable_entity
    end
  end

  # DELETE /cargo_guias/1
  def destroy
    @cargo_guia.destroy!
  end

  private

  def set_cargo_guia
    @cargo_guia = CargoGuia.find(params[:id])
  end

  def cargo_guia_params
    params.require(:cargo_guia).permit(:nome_do_cargo, :filtro_id)
  end
end
