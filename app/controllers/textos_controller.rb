class TextosController < ApplicationController
  before_action :set_texto, only: %i[ show update destroy ]
  wrap_parameters false

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    sort_column = params[:sort_by] || 'id'
    sort_direction = params[:direction] || 'desc'

    # Whitelist allowed columns for sorting
    allowed_columns = ['id', 'texto', 'prova_id', 'concurso_id', 'created_at']
    sort_column = 'id' unless allowed_columns.include?(sort_column)
    sort_direction = 'desc' unless ['asc', 'desc'].include?(sort_direction)

    @textos = Texto.all
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @textos = @textos.where("texto ILIKE ?", search_term)
    end

    total_count = @textos.count
    @textos = @textos.order("#{sort_column} #{sort_direction}")
                     .offset((page - 1) * per_page)
                     .limit(per_page)

    render json: {
      data: @textos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @texto
  end

  def all
    render json: Texto.select(:id, :texto).order(id: :desc)
  end

  def create
    @texto = Texto.new(texto_params)

    if @texto.save
      render json: @texto, status: :created
    else
      render json: @texto.errors, status: :unprocessable_entity
    end
  end

  def update
    if @texto.update(texto_params)
      render json: @texto
    else
      render json: @texto.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @texto.destroy!
  end

  private
    def set_texto
      @texto = Texto.find(params[:id])
    end

    def texto_params
      params.permit(:texto, :prova_id, :concurso_id, :imagem_texto)
    end
end
