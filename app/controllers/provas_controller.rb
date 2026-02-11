class ProvasController < ApplicationController
  before_action :set_prova, only: %i[ show update destroy questaos ]

  # GET /provas
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @provas = Prova.includes(:orgao, :banca, :concurso)
                   .offset((page - 1) * per_page)
                   .limit(per_page)

    render json: {
      data: @provas.as_json(include: [:orgao, :banca, :concurso]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Prova.count,
        total_pages: (Prova.count.to_f / per_page).ceil
      }
        }
      end

  def paginated_by_ano
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @provas = Prova.includes(:orgao, :banca, :concurso)
                    .order(ano: :desc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

    render json: {
      data: @provas.as_json(include: [:orgao, :banca, :concurso]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Prova.count,
        total_pages: (Prova.count.to_f / per_page).ceil
      }
    }
  end

  # GET /provas/all
  def all
    render json: Prova.order(:nome)
  end

  def questaos
    @questaos = @prova.questaos
    render json: @questaos
  end

  # GET /provas/1
  def show
    render json: @prova.as_json(include: [:orgao, :banca, :concurso])
  end

  # POST /provas
  def create
    @prova = Prova.new(prova_params)

    if @prova.save
      render json: @prova, status: :created, location: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /provas/1
  def update
    if @prova.update(prova_params)
      render json: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # DELETE /provas/1
  def destroy
    @prova.destroy!
  end

  private
    def set_prova
      @prova = Prova.find(params[:id])
    end

    def prova_params
      params.require(:prova).permit(:nome, :orgao_id, :banca_id, :concurso_id, :ano, :escolaridade, :pdfs_folder_url)
    end
end