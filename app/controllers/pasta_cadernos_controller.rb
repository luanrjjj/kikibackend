class PastaCadernosController < ApplicationController
  before_action :set_pasta_caderno, only: [:show, :update, :destroy]

  def index
    @pasta_cadernos = current_user.pasta_cadernos.includes(:cadernos)
    render json: @pasta_cadernos.as_json(include: :cadernos)
  end

  def show
    render json: @pasta_caderno.as_json(include: :cadernos)
  end

  def create
    @pasta_caderno = current_user.pasta_cadernos.new(pasta_caderno_params)

    if @pasta_caderno.save
      render json: @pasta_caderno, status: :created
    else
      render json: @pasta_caderno.errors, status: :unprocessable_entity
    end
  end

  def update
    if @pasta_caderno.update(pasta_caderno_params)
      render json: @pasta_caderno
    else
      render json: @pasta_caderno.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @pasta_caderno.destroy
    head :no_content
  end

  private

  def set_pasta_caderno
    @pasta_caderno = current_user.pasta_cadernos.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pasta não encontrada' }, status: :not_found
  end

  def pasta_caderno_params
    params.require(:pasta_caderno).permit(:nome)
  end
end
