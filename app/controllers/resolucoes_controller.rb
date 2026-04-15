class ResolucoesController < ApplicationController
  def create
    @questao = Questao.find(params[:resolucao][:questao_id])
    is_correct = @questao.correta == params[:resolucao][:resposta]

    @resolucao = current_user.resolucoes.new(resolucao_params)
    @resolucao.correta = is_correct

    if @resolucao.save
      render json: {
        resolucao: @resolucao,
        correta: is_correct,
        resposta_correta: @questao.correta
      }, status: :created
    else
      render json: @resolucao.errors, status: :unprocessable_entity
    end
  end

  private

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
