class OrgaosController < ApplicationController
  before_action :set_orgao, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    @orgaos = Orgao.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @orgaos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Orgao.count,
        total_pages: (Orgao.count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @orgao
  end

  def create
    @orgao = Orgao.new(orgao_params)

    if @orgao.save
      render json: @orgao, status: :created, location: @orgao
    else
      render json: @orgao.errors, status: :unprocessable_entity
    end
  end

  def update
    if @orgao.update(orgao_params)
      render json: @orgao
    else
      render json: @orgao.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @orgao.destroy!
  end

  private
    def set_orgao
      @orgao = Orgao.find(params[:id])
    end

    def orgao_params
      params.require(:orgao).permit(:nome, :sede, :logo_url)
    end
end