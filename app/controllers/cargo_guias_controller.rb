class CargoGuiasController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_cargo_guia, only: %i[ show update destroy ]

  # GET /cargo_guias
  def index
    if params[:guia_id].present?
      guia = Guia.find_by(id: params[:guia_id])
      cargo_ids = GuiaFiltro.where(guia_id: params[:guia_id]).select(:cargo_guia_id)
      @cargo_guias = CargoGuia.where(id: cargo_ids)
      
      result = @cargo_guias.map do |cg|
        json_cg = cg.as_json
        json_cg['filtros'] = cg.filtros_for_guia(guia)
        json_cg
      end
      render json: result
    else
      @cargo_guias = CargoGuia.all
      render json: @cargo_guias.as_json(methods: :filtros)
    end
  end

  # GET /cargo_guias/1
  def show
    if params[:guia_id].present?
      guia = Guia.find_by(id: params[:guia_id])
      json_cg = @cargo_guia.as_json
      json_cg['filtros'] = @cargo_guia.filtros_for_guia(guia)
      render json: json_cg
    else
      render json: @cargo_guia.as_json(methods: :filtros)
    end
  end

  # POST /cargo_guias
  def create
    @cargo_guia = CargoGuia.new(cargo_guia_params.except(:filtro_ids))
    
    incoming_fids = params[:filtro_ids] || (params[:cargo_guia] && params[:cargo_guia][:filtro_ids])

    if params[:guia_id].present? && incoming_fids.present?
      merge_filtro_ids_for_guia(params[:guia_id], incoming_fids)
    elsif incoming_fids.present?
      @cargo_guia.filtro_ids = incoming_fids
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
    @cargo_guia.assign_attributes(cargo_guia_params.except(:filtro_ids))
    
    incoming_fids = params[:filtro_ids] || (params[:cargo_guia] && params[:cargo_guia][:filtro_ids])

    if params[:guia_id].present? && incoming_fids.present?
      merge_filtro_ids_for_guia(params[:guia_id], incoming_fids)
    elsif incoming_fids.present?
      @cargo_guia.filtro_ids = incoming_fids
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
    permitted = params.require(:cargo_guia).permit(:nome_do_cargo)
    if params[:cargo_guia] && params[:cargo_guia][:filtro_ids]
      raw_val = params[:cargo_guia][:filtro_ids]
      if raw_val.is_a?(Array)
        permitted[:filtro_ids] = raw_val.map { |x| x.is_a?(ActionController::Parameters) ? x.to_unsafe_h : x }
      elsif raw_val.is_a?(ActionController::Parameters)
        permitted[:filtro_ids] = raw_val.to_unsafe_h
      else
        permitted[:filtro_ids] = raw_val
      end
    end
    permitted
  end

  def sync_guia_links(guia_id)
    guia = Guia.find_by(id: guia_id)
    return unless guia
    
    fids = @cargo_guia.filtros_for_guia(guia).pluck(:id)
    if fids.any?
      GuiaFiltro.where(guia_id: guia_id, cargo_guia_id: @cargo_guia.id).destroy_all
      filtro1 = Filtro.find_by(id: fids[0])
      nome_default = filtro1&.nome_do_filtro || "Caderno #{fids[0]}"
      GuiaFiltro.create!(
        guia_id: guia_id,
        cargo_guia_id: @cargo_guia.id,
        nome: nome_default,
        filtro_id_1: fids[0],
        filtro_id_2: fids[1],
        filtro_id_3: fids[2]
      )
    else
      unless GuiaFiltro.exists?(guia_id: guia_id, cargo_guia_id: @cargo_guia.id)
        GuiaFiltro.create!(
          guia_id: guia_id,
          cargo_guia_id: @cargo_guia.id,
          nome: "Geral"
        )
      end
    end
  end

  def merge_filtro_ids_for_guia(guia_id, incoming_filtro_ids)
    guia = Guia.find_by(id: guia_id)
    return unless guia

    existing = @cargo_guia.filtro_ids
    existing_array = if existing.is_a?(Array)
                       existing.map { |x| x.is_a?(Hash) ? x : nil }.compact
                     elsif existing.is_a?(Hash)
                       [existing]
                     else
                       []
                     end

    existing_array.reject! { |item| item.key?(guia.nome) }
    existing_array << { guia.nome => Array(incoming_filtro_ids).map(&:to_i) }
    @cargo_guia.filtro_ids = existing_array
  end
end
