class ComentariosController < ApplicationController
  before_action :authenticate_user! # Ensure user is logged in
  before_action :set_questao, only: [:index, :create]

  # GET /comentarios?questao_id=1
  def index
    if @questao
      @comentarios = @questao.comentarios.includes(:user).order(votos_soma: :desc, created_at: :desc)
      render json: @comentarios.as_json(include: { user: { only: [:id, :name, :email] } })
    else
      render json: { error: 'Questão não encontrada' }, status: :not_found
    end
  end

  # POST /comentarios
  def create
    if @questao
      @comentario = @questao.comentarios.new(comentario_params)
      @comentario.user = current_user

      if @comentario.save
        render json: @comentario.as_json(include: { user: { only: [:id, :name, :email] } }), status: :created
      else
        render json: @comentario.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Questão não encontrada' }, status: :not_found
    end
  end

  private

  def set_questao
    id = params[:questao_id] || (params[:comentario] && params[:comentario][:questao_id])
    @questao = Questao.find(id) if id.present?
  rescue ActiveRecord::RecordNotFound
    @questao = nil
  end

  def comentario_params
    params.require(:comentario).permit(:texto, :questao_id, :prova_id, :concurso_id)
  end
end
