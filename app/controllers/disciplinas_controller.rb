class DisciplinasController < ApplicationController
  before_action :set_disciplina, only: %i[ show update destroy ]
  before_action :authenticate_admin!, only: %i[ index all ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    sort_column = params[:sort_by].presence || 'questoes_count'
    sort_direction = params[:direction].presence || (params[:sort_by].blank? ? 'desc' : 'asc')

    allowed_columns = {
      'id' => 'disciplinas.id',
      'nome' => 'disciplinas.nome',
      'created_at' => 'disciplinas.created_at',
      'questoes_count' => 'COUNT(questaos.id)',
      'questaos_count' => 'COUNT(questaos.id)'
    }

    order_sql = allowed_columns[sort_column] || 'COUNT(questaos.id)'
    direction_sql = ['asc', 'desc'].include?(sort_direction.to_s.downcase) ? sort_direction.to_s.downcase : 'desc'

    base_scope = Disciplina.all
    if params[:search].present?
      base_scope = base_scope.where("disciplinas.nome ILIKE ?", "%#{params[:search]}%")
    end

    total_count = base_scope.count

    @disciplinas = base_scope
                    .left_joins(:questaos)
                    .select("disciplinas.*, COUNT(questaos.id) AS meucount")
                    .group("disciplinas.id")
                    .order(Arel.sql("#{order_sql} #{direction_sql}, disciplinas.id DESC"))
                    .offset((page - 1) * per_page)
                    .limit(per_page)

    data_result = @disciplinas.map do |d|
      q_count = d.attributes["meucount"].to_i
      d.as_json.merge(
        questoes_count: q_count,
        questaos_count: q_count,
        total_questoes: q_count
      )
    end

    render json: {
      data: data_result,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def all
    result = Rails.cache.fetch("disciplinas/all", expires_in: 24.hours) do
      Disciplina.select(:id, :nome).order(:nome).to_a
    end
    render json: result
  end

  def filters
    scope = Disciplina.order(:nome)
    scope = scope.where('nome ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    render json: scope.pluck(:id, :nome).map { |id, nome| { id: id, nome: nome } }
  end

  def show
    render json: @disciplina
  end

  def create
    @disciplina = Disciplina.new(disciplina_params)

    if @disciplina.save
      Rails.cache.delete("disciplinas/all")
      render json: @disciplina, status: :created, location: @disciplina
    else
      render json: @disciplina.errors, status: :unprocessable_entity
    end
  end

  def update
    if @disciplina.update(disciplina_params)
      Rails.cache.delete("disciplinas/all")
      render json: @disciplina
    else
      render json: @disciplina.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @disciplina.destroy!
    Rails.cache.delete("disciplinas/all")
  end

  private
    def set_disciplina
      @disciplina = Disciplina.find(params[:id])
    end

    def disciplina_params
      params.require(:disciplina).permit(:nome)
    end
end