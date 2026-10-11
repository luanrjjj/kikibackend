class ProvaQuestaosController < ApplicationController
  def index
    if params[:prova_id].present?
      if Prova.blocked.exists?(id: params[:prova_id]) && !admin_user?
        return render json: { error: 'Prova não encontrada' }, status: :not_found
      end

      @prova_questaos = ProvaQuestao.where(prova_id: params[:prova_id])
                                    .order(:numero_questao)
                                    .includes(questao: [:assunto, :disciplina, :texto])
      
      render json: ProvaQuestaoSerializer.new(@prova_questaos).serializable_hash
    else
      render json: { error: 'prova_id is required' }, status: :bad_request
    end
  end
end
