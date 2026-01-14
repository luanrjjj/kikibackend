class AssuntosController < ApplicationController
  before_action :set_assunto, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @assuntos = Assunto.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @assuntos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Assunto.count,
        total_pages: (Assunto.count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @assunto
  end

  def create
    @assunto = Assunto.new(assunto_params)

    if @assunto.save
      render json: @assunto, status: :created, location: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def update
    if @assunto.update(assunto_params)
      render json: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @assunto.destroy!
  end

  private
    def set_assunto
      @assunto = Assunto.find(params[:id])
    end

    def assunto_params
      params.require(:assunto).permit(:nome, :disciplina_id)
    end
end