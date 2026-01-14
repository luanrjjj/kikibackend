class ConcursosController < ApplicationController
  before_action :set_concurso, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @concursos = Concurso.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @concursos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Concurso.count,
        total_pages: (Concurso.count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @concurso
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

  private
    def set_concurso
      @concurso = Concurso.find(params[:id])
    end

    def concurso_params
      params.require(:concurso).permit(:nome, :inscricoes_ate, :edital_nome, :banca_id, :orgao_id, :cargos)
    end
end
