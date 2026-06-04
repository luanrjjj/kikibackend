class FiltrosController < ApplicationController
  def index
    @filtros = Filtro.joins(:user).order(created_at: :desc)
    
    if params[:admin_only] == 'true'
      @filtros = @filtros.where(users: { admin: true })
    else
      @filtros = @filtros.where(user_id: current_user.id)
    end

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

  def all
    @filtros = Filtro.joins(:user).where(users: { admin: true }).select(:id, :nome_do_filtro).order(:nome_do_filtro)
    
    if params[:search].present?
      @filtros = @filtros.where("nome_do_filtro ILIKE ?", "%#{params[:search]}%")
    end

    @filtros = @filtros.limit(50) if params[:search].present?

    render json: @filtros
  end

  private

  def filtro_params
    params.require(:filtro).permit(
      :nome_do_filtro,
      filtro: [
        :id_da_disciplina, 
        :nome_da_disciplina, 
        { assuntos: [] }, 
        { topicos: [] }, 
        { disciplinas: [] }, 
        { bancas: [] }, 
        { orgaos: [] }, 
        { ano: [] }, 
        { escolaridades: [] }, 
        { activeFilters: [:id, :label, :type] }
      ]
    )
  end
end
