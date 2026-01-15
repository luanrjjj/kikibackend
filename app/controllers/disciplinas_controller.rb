class DisciplinasController < ApplicationController
  before_action :set_disciplina, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @disciplinas = Disciplina.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @disciplinas,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Disciplina.count,
        total_pages: (Disciplina.count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @disciplina
  end

  def create
    @disciplina = Disciplina.new(disciplina_params)

    if @disciplina.save
      render json: @disciplina, status: :created, location: @disciplina
    else
      render json: @disciplina.errors, status: :unprocessable_entity
    end
  end

  def update
    if @disciplina.update(disciplina_params)
      render json: @disciplina
    else
      render json: @disciplina.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @disciplina.destroy!
  end

  private
    def set_disciplina
      @disciplina = Disciplina.find(params[:id])
    end

    def disciplina_params
      params.require(:disciplina).permit(:nome)
    end
end