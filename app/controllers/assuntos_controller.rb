class AssuntosController < ApplicationController
  before_action :set_assunto, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @assuntos = Assunto.all
    if params[:search].present?
      @assuntos = @assuntos.where("nome ILIKE ?", "%#{params[:search]}%")
    end

    total_count = @assuntos.count
    @assuntos = @assuntos.order(:nome).offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @assuntos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def all
    result = Rails.cache.fetch("assuntos/all", expires_in: 24.hours) do
      Assunto.select(:id, :nome, :disciplina_id).order(:nome).to_a
    end
    render json: result
  end

  def filters
    scope = Assunto.order(:nome)
    scope = scope.where('nome ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    render json: scope.pluck(:id, :nome, :disciplina_id).map { |id, nome, d_id| { id: id, nome: nome, disciplina_id: d_id } }
  end

  def show
    render json: @assunto
  end

  def create
    @assunto = Assunto.new(assunto_params)

    if @assunto.save
      Rails.cache.delete("assuntos/all")
      render json: @assunto, status: :created, location: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def update
    if @assunto.update(assunto_params)
      Rails.cache.delete("assuntos/all")
      render json: @assunto
    else
      render json: @assunto.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @assunto.destroy!
    Rails.cache.delete("assuntos/all")
  end

  private
    def set_assunto
      @assunto = Assunto.find(params[:id])
    end

    def assunto_params
      params.require(:assunto).permit(:nome, :disciplina_id)
    end
end