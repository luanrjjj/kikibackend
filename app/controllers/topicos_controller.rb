class TopicosController < ApplicationController
  before_action :set_topico, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @topicos = Topico.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @topicos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Topico.count,
        total_pages: (Topico.count.to_f / per_page).ceil
      }
    }
  end

  def all
    result = Rails.cache.fetch("topicos/all", expires_in: 24.hours) do
      Topico.select(:id, :nome, :disciplina_id, :assunto_id).order(:nome).to_a
    end
    render json: result
  end

  def show
    render json: @topico
  end

  def create
    @topico = Topico.new(topico_params)

    if @topico.save
      Rails.cache.delete("topicos/all")
      render json: @topico, status: :created, location: @topico
    else
      render json: @topico.errors, status: :unprocessable_entity
    end
  end

  def update
    if @topico.update(topico_params)
      Rails.cache.delete("topicos/all")
      render json: @topico
    else
      render json: @topico.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @topico.destroy!
    Rails.cache.delete("topicos/all")
  end

  private
    def set_topico
      @topico = Topico.find(params[:id])
    end

    def topico_params
      params.require(:topico).permit(:nome, :disciplina_id, :assunto_id)
    end
end
