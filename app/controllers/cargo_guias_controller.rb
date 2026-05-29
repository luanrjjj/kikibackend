class CargoGuiasController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_cargo_guia, only: %i[ show update destroy ]

  # GET /cargo_guias
  def index
    if params[:guia_id].present?
      # Use a subquery to avoid JOIN + DISTINCT on JSON columns
      cargo_ids = GuiaFiltro.where(guia_id: params[:guia_id]).select(:cargo_guia_id)
      @cargo_guias = CargoGuia.where(id: cargo_ids)
    else
      @cargo_guias = CargoGuia.all
    end
    render json: @cargo_guias.as_json(methods: :filtros)
  end

  # GET /cargo_guias/1
  def show
    render json: @cargo_guia.as_json(methods: :filtros)
  end

  # POST /cargo_guias
  def create
    @cargo_guia = CargoGuia.new(cargo_guia_params)
    
    # Fallback in case they are sent at root level
    if params[:filtro_ids].present? && @cargo_guia.filtro_ids.blank?
      @cargo_guia.filtro_ids = params[:filtro_ids]
    end

    if @cargo_guia.save
      if params[:guia_id].present?
        sync_guia_links(params[:guia_id])
      end
      render json: @cargo_guia.as_json(methods: :filtros), status: :created
    else
      render json: @cargo_guia.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /cargo_guias/1
  def update
    @cargo_guia.assign_attributes(cargo_guia_params)
    
    # Fallback in case they are sent at root level
    if params[:filtro_ids].present?
      @cargo_guia.filtro_ids = params[:filtro_ids]
    end

    if @cargo_guia.save
      if params[:guia_id].present?
        sync_guia_links(params[:guia_id])
      end
      render json: @cargo_guia.as_json(methods: :filtros)
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
    params.require(:cargo_guia).permit(:nome_do_cargo, filtro_ids: [])
  end

  def sync_guia_links(guia_id)
    # Ensure all filters in this cargo are linked to the guide via guia_filtros
    # First, clear old links for this specific cargo-guia pair
    GuiaFiltro.where(guia_id: guia_id, cargo_guia_id: @cargo_guia.id).destroy_all
    
    # Create new links
    Array(@cargo_guia.filtro_ids).each do |fid|
      next if fid.blank?
      GuiaFiltro.create!(guia_id: guia_id, cargo_guia_id: @cargo_guia.id, filtro_id: fid)
    end
  end
end
