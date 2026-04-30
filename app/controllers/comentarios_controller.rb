class ComentariosController < ApplicationController
  before_action :set_questao, only: [:index, :create]

  # GET /comentarios?questao_id=1
  def index
    if @questao
      @comentarios = @questao.comentarios.includes(:user).order(created_at: :desc)
      render json: @comentarios.as_json(include: { user: { only: [:id, :name, :email] } })
    else
      render json: { error: 'Questão não encontrada' }, status: :not_found
    end
  end

  # POST /comentarios
  def create
    @comentario = @questao.comentarios.new(comentario_params)
    @comentario.user = current_user # Assuming current_user is available

    if @comentario.save
      render json: @comentario.as_json(include: { user: { only: [:id, :name, :email] } }), status: :created
    else
      render json: @comentario.errors, status: :unprocessable_entity
    end
  end

  private

  def set_questao
    @questao = Questao.find(params[:questao_id]) if params[:questao_id].present?
  end

  def comentario_params
    params.require(:comentario).permit(:texto, :questao_id, :prova_id, :concurso_id)
  end
end
