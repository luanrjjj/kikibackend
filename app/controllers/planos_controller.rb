class PlanosController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  before_action :verify_admin!, except: [:index]

  def index
    @planos = Plano.all
    render json: @planos
  end

  def create
    @plano = Plano.new(plano_params)
    if @plano.save
      render json: @plano, status: :created
    else
      render json: { error: @plano.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    @plano = Plano.find(params[:id])
    if @plano.update(plano_params)
      render json: @plano
    else
      render json: { error: @plano.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @plano = Plano.find(params[:id])
    @plano.destroy
    head :no_content
  end

  private

  def plano_params
    params.require(:plano).permit(
      :nome_do_plano, :valor_mensal, :valor_promocional_mensal,
      :valor_anual, :valor_promocional_anual,
      :data_inicio_promocao, :data_fim_promocao,
      variaveis: []
    )
  end

  def verify_admin!
    authenticate_user!
    render json: { error: "Acesso negado" }, status: :forbidden unless current_user.admin?
  end
end
