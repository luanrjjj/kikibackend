class CadernosController < ApplicationController
  before_action :set_caderno, only: %i[ show questaos destroy ]

  # GET /cadernos
  def index
    @cadernos = current_user.cadernos.order(created_at: :desc)
    render json: @cadernos
  end

  # GET /cadernos/1
  def show
    render json: @caderno
  end

  # GET /cadernos/1/questaos
  def questaos
    @questaos = Questao.where(id: @caderno.questoes_ids)
                       .includes(:disciplina, :assunto, :concurso, :texto, :provas, concurso: :orgao, provas: :orgao)
    
    # Optional: order questions by their original position in the questoes_ids array
    # This ensures consistency for the user
    ordered_questaos = @caderno.questoes_ids.map { |id| @questaos.find { |q| q.id == id.to_i } }.compact

    render json: QuestaoSerializer.new(ordered_questaos).serializable_hash
  end

  # POST /cadernos
  def create
    @caderno = current_user.cadernos.new(caderno_params)

    if @caderno.save
      render json: @caderno, status: :created
    else
      render json: @caderno.errors, status: :unprocessable_entity
    end
  end

  # DELETE /cadernos/1
  def destroy
    @caderno.destroy!
  end

  private

  def set_caderno
    @caderno = current_user.cadernos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Caderno não encontrado' }, status: :not_found
  end

  def caderno_params
    params.require(:caderno).permit(:nome, :nome_da_pasta, :prova_id, :questoes_ids => [])
  end
end
