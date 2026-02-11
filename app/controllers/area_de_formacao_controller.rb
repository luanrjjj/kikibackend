class AreaDeFormacaoController < ApplicationController
  def index
    @area_de_formacoes = AreaDeFormacao.all
    render json: @area_de_formacoes
  end

  def show
    @area_de_formacao = AreaDeFormacao.find(params[:id])
    render json: @area_de_formacao
  end
end
