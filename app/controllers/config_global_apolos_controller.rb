class ConfigGlobalApolosController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_config, only: %i[ show update destroy ]

  # GET /config_global_apolos
  def index
    @configs = ConfigGlobalApolo.all.order(:nome_da_variavel)
    render json: @configs
  end

  # GET /config_global_apolos/1
  def show
    render json: @config
  end

  # POST /config_global_apolos
  def create
    @config = ConfigGlobalApolo.new(config_params)

    if @config.save
      render json: @config, status: :created
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /config_global_apolos/1
  def update
    if @config.update(config_params)
      render json: @config
    else
      render json: @config.errors, status: :unprocessable_entity
    end
  end

  # DELETE /config_global_apolos/1
  def destroy
    @config.destroy!
  end

  private

  def set_config
    @config = ConfigGlobalApolo.find(params[:id])
  end

  def config_params
    params.require(:config_global_apolo).permit(:nome_da_variavel, :valor_da_variavel)
  end
end
