class PlanosController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @planos = Plano.all
    render json: @planos
  end
end
