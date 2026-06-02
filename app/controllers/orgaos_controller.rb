class OrgaosController < ApplicationController
  before_action :set_orgao, only: %i[ show update destroy ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max
    sort_column = params[:sort_by] || 'nome'
    sort_direction = params[:direction] || 'asc'

    # Whitelist allowed columns for sorting to prevent SQL injection
    allowed_columns = ['id', 'nome', 'sigla', 'esfera', 'created_at']
    sort_column = 'nome' unless allowed_columns.include?(sort_column)
    sort_direction = 'asc' unless ['asc', 'desc'].include?(sort_direction)
    
    @orgaos = Orgao.all
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orgaos = @orgaos.where("nome ILIKE ? OR sigla ILIKE ?", search_term, search_term)
    end

    total_count = @orgaos.count
    @orgaos = @orgaos.order("#{sort_column} #{sort_direction}")
                         .offset((page - 1) * per_page)
                         .limit(per_page)

    render json: {
      data: @orgaos,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    render json: @orgao
  end

  def all
    render json: Orgao.select(:id, :nome, :sigla).order(:nome)
  end

  def filters
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 100).to_i, 1].max
    
    scope = Orgao.order(:nome)
    scope = scope.where('nome ILIKE ? OR sigla ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    
    total_count = scope.count
    paged_scope = scope.offset((page - 1) * per_page).limit(per_page)
    
    results = paged_scope.pluck(:id, :nome, :sigla, :esfera).map { |id, nome, sigla, esfera| { id: id, nome: nome, sigla: sigla, esfera: esfera } }
    
    render json: {
      data: results,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil,
        next_page: page < (total_count.to_f / per_page).ceil ? page + 1 : nil
      }
    }
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
      params.require(:orgao).permit(:nome, :sigla, :sede, :logo_url)
    end
end