class QuestaosController < ApplicationController
  before_action :set_questao, only: %i[ show update destroy ]

  # GET /questaos
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @questaos = Questao.includes(:prova, :assunto, :disciplina)
                       .offset((page - 1) * per_page)
                       .limit(per_page)

    render json: {
      data: @questaos.as_json(include: [:prova, :assunto, :disciplina]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Questao.count,
        total_pages: (Questao.count.to_f / per_page).ceil
      }
    }
  end



  # GET /questaos/1
  def show
    render json: @questao.as_json(include: [:prova, :assunto, :disciplina, :textos])
  end

  # POST /questaos
  def create
    @questao = Questao.new(questao_params)

    if @questao.save
      render json: @questao, status: :created, location: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /questaos/1
  def update
    if @questao.update(questao_params)
      render json: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # DELETE /questaos/1
  def destroy
    @questao.destroy!
  end


   # GET /questaos/count
    def count
    @questaos = Questao.distinct

    if params[:bancas].present?
      @questaos = @questaos.joins(prova: :banca).where(bancas: { id: params[:bancas] })
    end

    if params[:ano].present?
      if params[:ano].to_s.include?('-')
        start_year, end_year = params[:ano].split('-').map(&:to_i)
        @questaos = @questaos.where(ano: start_year..end_year)
      else
        @questaos = @questaos.where(ano: params[:ano])
      end
    end

    if params[:escolaridade].present?
      @questaos = @questaos.joins(prova: :cargo).where(cargos: { escolaridade: params[:escolaridade] })
    end

    render json: { count: @questaos.count }
  end

  #GET /questao/filters_page_questaos
  def filters_questaos
    @questaos = Questao.distinct

    if params[:bancas].present?
      @questaos = @questaos.joins(prova: :banca).where(bancas: { id: params[:bancas] })
    end

    if params[:ano].present?
      if params[:ano].to_s.include?('-')
        start_year, end_year = params[:ano].split('-').map(&:to_i)
        @questaos = @questaos.where(ano: start_year..end_year)
      else
        @questaos = @questaos.where(ano: params[:ano])
      end
    end

    if params[:escolaridade].present?
      @questaos = @questaos.joins(prova: :cargo).where(cargos: { escolaridade: params[:escolaridade] })
    end

    total_count = @questaos.count
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    @questaos = @questaos.offset((page - 1) * per_page).limit(per_page)


    render json: { questoes: @questaos, total_count: total_count }
  end

  private
    def set_questao
      @questao = Questao.find(params[:id])
    end

    def questao_params
      params.require(:questao).permit(
        :texto, :enunciado, :discursiva, :ano, :correta,
        :prova_id, :concurso_id, :assunto_id, :disciplina_id,
        alternativas: [:value, :text]
      )
    end
end