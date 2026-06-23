class EditalVertController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_edital_vert, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    
    @editais = EditalVert.all

    if params[:search].present?
      @editais = @editais.left_outer_joins(:concurso, :prova)
                         .where("edital_vert.cargo ILIKE :search OR concursos.nome ILIKE :search OR provas.nome ILIKE :search", search: "%#{params[:search]}%")
    end

    total_count = @editais.count
    @editais = @editais.order(created_at: :desc)
                       .offset((page - 1) * per_page)
                       .limit(per_page)

    render json: {
      data: @editais.as_json(include: { 
        concurso: { only: [:id, :nome] }, 
        prova: { only: [:id, :nome] } 
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def all
    @editais = EditalVert.all.order(created_at: :desc)
    render json: @editais.as_json(include: { 
      concurso: { only: [:id, :nome] }, 
      prova: { only: [:id, :nome] } 
    })
  end

  def show
    render json: @edital_vert.as_json(include: { 
      concurso: { only: [:id, :nome] }, 
      prova: { only: [:id, :nome] } 
    })
  end

  def create
    @edital_vert = EditalVert.new(edital_vert_params)

    if @edital_vert.save
      render json: @edital_vert, status: :created
    else
      render json: @edital_vert.errors, status: :unprocessable_entity
    end
  end

  def update
    if @edital_vert.update(edital_vert_params)
      render json: @edital_vert
    else
      render json: @edital_vert.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @edital_vert.destroy!
    head :no_content
  end

  private

  def set_edital_vert
    @edital_vert = EditalVert.find(params[:id])
  end

  def edital_vert_params
    permitted = params.require(:edital_vert).permit(:concurso_id, :cargo, :prova_id, :texto_verticalizado)
    if params[:edital_vert] && params[:edital_vert][:texto_json_disciplina]
      raw_json = params[:edital_vert][:texto_json_disciplina]
      if raw_json.is_a?(ActionController::Parameters)
        permitted[:texto_json_disciplina] = raw_json.to_unsafe_h
      elsif raw_json.respond_to?(:to_unsafe_h)
        permitted[:texto_json_disciplina] = raw_json.to_unsafe_h
      elsif raw_json.is_a?(Hash)
        permitted[:texto_json_disciplina] = raw_json
      elsif raw_json.is_a?(Array)
        permitted[:texto_json_disciplina] = raw_json.map { |val| val.respond_to?(:to_unsafe_h) ? val.to_unsafe_h : (val.is_a?(Hash) ? val : val) }
      else
        permitted[:texto_json_disciplina] = raw_json
      end
    end
    permitted
  end
end
