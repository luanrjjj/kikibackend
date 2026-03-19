class ConcursosController < ApplicationController
  before_action :set_concurso, only: %i[ show update destroy ]
  skip_before_action :authenticate_user!, only: [:public_index]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @concursos = Concurso.includes(:banca, :orgao).offset((page - 1) * per_page).limit(per_page)
    puts @concursos
    render json: {
      data: @concursos.as_json(include: [:banca, :orgao]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Concurso.count,
        total_pages: (Concurso.count.to_f / per_page).ceil
      }
    }
  end

  def public_index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 10).to_i, 1].max
    
    @concursos = Concurso.includes(:banca, :provas, :orgao)
    
    if params[:banca_id].present?
      @concursos = @concursos.where(banca_id: params[:banca_id])
    end

    if params[:ano].present?
      @concursos = @concursos.joins(:provas).where(provas: { ano: params[:ano] }).distinct
    end

    total_count = @concursos.count
    @concursos = @concursos.order(inscricoes_ate: :desc)
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @concursos.as_json(include: { 
        banca: { only: [:id, :nome, :sigla] },
        orgao: { only: [:id, :nome, :logo_url] },
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

  def all
    render json: Disciplina.order(:nome)
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
