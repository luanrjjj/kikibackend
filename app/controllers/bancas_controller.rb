class BancasController < ApplicationController
  before_action :set_banca, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @bancas = Banca.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @bancas,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Banca.count,
        total_pages: (Banca.count.to_f / per_page).ceil
      }
    }
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