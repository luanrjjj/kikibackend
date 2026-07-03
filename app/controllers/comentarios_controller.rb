class ComentariosController < ApplicationController
  before_action :authenticate_user! # Ensure user is logged in
  before_action :set_questao, only: [:index, :create]
  before_action :set_comentario, only: [:upvote, :downvote]

  # GET /comentarios?questao_id=1
  def index
    if @questao
      @comentarios = @questao.comentarios.includes(:user).order(created_at: :desc)
      
      # Inclui o voto do usuário atual se estiver logado
      comentarios_json = @comentarios.as_json(include: { user: { only: [:id, :name, :email], methods: [:assinatura, :total_resolucoes, :percentual_acerto] } })
      
      if current_user
        votos_do_usuario = VotoComentario.where(user: current_user, comentario_id: @comentarios.pluck(:id))
                                         .pluck(:comentario_id, :valor).to_h
        
        comentarios_json.each do |c|
          c['user_voto'] = votos_do_usuario[c['id']]
        end
      end

      render json: comentarios_json
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
        render json: @comentario.as_json(include: { user: { only: [:id, :name, :email], methods: [:assinatura, :total_resolucoes, :percentual_acerto] } }), status: :created
      else
        render json: @comentario.errors, status: :unprocessable_entity
      end
    else
      render json: { error: 'Questão não encontrada' }, status: :not_found
    end
  end

  # PATCH /comentarios/:id/upvote
  def upvote
    voto = VotoComentario.find_or_initialize_by(user: current_user, comentario: @comentario)
    old_valor = voto.persisted? ? voto.valor : 0
    
    if old_valor == 1
      # Se já for um upvote, remove o voto (toggle off)
      voto.destroy
      @comentario.update!(votos_soma: @comentario.votos_soma - 1)
    else
      # Se for neutro ou downvote, vira upvote
      voto.valor = 1
      if voto.save
        @comentario.update!(votos_soma: @comentario.votos_soma - old_valor + 1)
      end
    end

    render json: { votos_soma: @comentario.votos_soma, user_voto: @comentario.voto_comentarios.find_by(user: current_user)&.valor }
  end

  # PATCH /comentarios/:id/downvote
  def downvote
    voto = VotoComentario.find_or_initialize_by(user: current_user, comentario: @comentario)
    old_valor = voto.persisted? ? voto.valor : 0
    
    if old_valor == -1
      # Se já for um downvote, remove o voto (toggle off)
      voto.destroy
      @comentario.update!(votos_soma: @comentario.votos_soma + 1)
    else
      # Se for neutro ou upvote, vira downvote
      voto.valor = -1
      if voto.save
        @comentario.update!(votos_soma: @comentario.votos_soma - old_valor - 1)
      end
    end

    render json: { votos_soma: @comentario.votos_soma, user_voto: @comentario.voto_comentarios.find_by(user: current_user)&.valor }
  end

  private

  def set_comentario
    @comentario = Comentario.find(params[:id])
  end

  def set_questao
    id = params[:questao_id] || (params[:comentario] && params[:comentario][:questao_id])
    @questao = Questao.find_by!(id: id) if id.present?
  rescue ActiveRecord::RecordNotFound
    @questao = nil
  end

  def comentario_params
    params.require(:comentario).permit(:texto, :questao_id, :prova_id, :concurso_id)
  end
end
