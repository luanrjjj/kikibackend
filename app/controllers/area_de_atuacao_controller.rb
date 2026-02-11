class AreaDeAtuacaoController < ApplicationController
  def index
    @area_de_atuacoes = AreaDeAtuacao.all
    render json: @area_de_atuacoes
  end

  def show
    @area_de_atuacao = AreaDeAtuacao.find(params[:id])
    render json: @area_de_atuacao
  end
end
