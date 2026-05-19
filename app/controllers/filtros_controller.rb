class FiltrosController < ApplicationController
  def index
    @filtros = current_user.filtros.order(created_at: :desc)
    render json: @filtros
  end

  def create
    @filtro = current_user.filtros.new(filtro_params)

    if @filtro.save
      render json: @filtro, status: :created
    else
      render json: @filtro.errors, status: :unprocessable_entity
    end
  end

  private

  def filtro_params
    params.require(:filtro).permit(
      :nome_do_filtro,
      filtro: [:id_da_disciplina, :nome_da_disciplina, { assuntos: [] }, { bancas: [] }, { orgaos: [] }, { ano: [] }]
    )
  end
end
