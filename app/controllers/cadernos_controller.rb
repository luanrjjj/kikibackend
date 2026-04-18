class CadernosController < ApplicationController
  before_action :set_caderno, only: %i[ show questaos destroy ]

  # GET /cadernos
  def index
    @cadernos = current_user.cadernos.order(created_at: :desc)
    
    # Enrich each caderno with stats
    cadernos_with_stats = @cadernos.map do |caderno|
      res_counts = caderno.resolucoes.group(:correta).count
      total_resolucoes = res_counts.values.sum
      
      caderno.as_json.merge(
        acertos: res_counts[true] || 0,
        erros: res_counts[false] || 0,
        total_questoes: caderno.questoes_ids&.length || 0,
        respondidas: total_resolucoes
      )
    end

    render json: cadernos_with_stats
  end

  # GET /cadernos/1
  def show
    render json: @caderno
  end

  # GET /cadernos/1/questaos
  def questaos
    @questaos = Questao.where(id: @caderno.questoes_ids)
                       .includes(:disciplina, :assunto, :concurso, :texto, :provas, concurso: :orgao, provas: :orgao)
    
    resolucoes = current_user.resolucoes.where(caderno_id: @caderno.id, questao_id: @caderno.questoes_ids)

    ordered_questaos = @caderno.questoes_ids.map { |id| @questaos.find { |q| q.id == id.to_i } }.compact

    render json: QuestaoSerializer.new(ordered_questaos, { 
      params: { 
        resolucoes: resolucoes.index_by(&:questao_id) 
      } 
    }).serializable_hash
  end

  # POST /cadernos
  def create
    if caderno_params[:nome_da_pasta].present? && caderno_params[:pasta_caderno_id].blank?
      pasta = current_user.pasta_cadernos.find_or_create_by!(nome: caderno_params[:nome_da_pasta])
      @caderno = current_user.cadernos.new(caderno_params.except(:nome_da_pasta).merge(pasta_caderno_id: pasta.id))
    else
      @caderno = current_user.cadernos.new(caderno_params.except(:nome_da_pasta))
    end

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
    params.require(:caderno).permit(:nome, :nome_da_pasta, :pasta_caderno_id, :prova_id, :questoes_ids => [])
  end
end
