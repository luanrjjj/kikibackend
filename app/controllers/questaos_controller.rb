class QuestaosController < ApplicationController
  before_action :authenticate_subscription, only: %i[ filters_questaos ]
  before_action :set_questao, only: %i[ show update destroy validate ]
  before_action :authenticate_admin!, only: %i[ index stats ]

  # GET /questaos
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    @questaos = Questao.includes(:provas, :assunto, :disciplina).order(id: :asc)

    if params[:disciplina_id].present?
      @questaos = @questaos.where(disciplina_id: params[:disciplina_id])
    end

    if params[:prova_id].present?
      @questaos = @questaos.joins(:prova_questaos).where(prova_questaos: { prova_id: params[:prova_id] })
    end

    if params[:assunto_id].present?
      @questaos = @questaos.where(assunto_id: params[:assunto_id])
    end

    if params[:search].present?
      @questaos = @questaos.where('enunciado ILIKE ?', "%#{params[:search]}%")
    end

    total_count = @questaos.count

    @questaos = @questaos.offset((page - 1) * per_page)
                       .limit(per_page)

    render json: {
      data: @questaos.as_json(include: [:provas, :assunto, :disciplina]),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /questaos/stats
  def stats
    conditions = []
    query_params = {}

    if params[:disciplina_id].present?
      conditions << "disciplina_id = {disciplina_id:Int64}"
      query_params[:disciplina_id] = params[:disciplina_id].to_i
    end

    if params[:assunto_id].present?
      conditions << "assunto_id = {assunto_id:Int64}"
      query_params[:assunto_id] = params[:assunto_id].to_i
    end

    if params[:prova_id].present?
      conditions << "prova_id = {prova_id:Int64}"
      query_params[:prova_id] = params[:prova_id].to_i
    end

    where_clause = conditions.any? ? "WHERE #{conditions.join(' AND ')}" : ""

    # Use ClickHouse for stats
    stats_query = <<~SQL
      SELECT 
        count() AS total,
        countIf(validado_admin IS NOT NULL) AS validated,
        countIf(correta IS NOT NULL AND correta != '') AS with_correct,
        countIf(disciplina_id > 0) AS with_disciplina,
        countIf(assunto_id > 0) AS with_assunto,
        countIf(disciplina_id > 0 AND assunto_id > 0) AS with_disciplina_assunto
      FROM questaos
      #{where_clause}
    SQL
    
    stats_data = ClickhouseSyncService.client.query(stats_query, query_params).to_hashes.first

    by_year_query = <<~SQL
      SELECT ano, count() as count 
      FROM questaos 
      #{where_clause}
      GROUP BY ano 
      ORDER BY ano ASC
    SQL
    
    by_year_raw = ClickhouseSyncService.client.query(by_year_query, query_params).to_hashes
    by_year = by_year_raw.each_with_object({}) { |row, hash| hash[row['ano']] = row['count'] }

    render json: {
      total_count: stats_data['total'] || 0,
      validated_count: stats_data['validated'] || 0,
      with_correct_answer_count: stats_data['with_correct'] || 0,
      with_disciplina_count: stats_data['with_disciplina'] || 0,
      with_assunto_count: stats_data['with_assunto'] || 0,
      with_disciplina_assunto_count: stats_data['with_disciplina_assunto'] || 0,
      by_year: by_year
    }
  end

  def validate
    if @questao.update(validado_admin: Time.current)
      render json: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # GET /questaos/1
  def show
    render json: @questao.as_json(include: [:provas, :assunto, :disciplina, :texto])
  end

  # POST /questaos
  def create
    @questao = Questao.new(questao_params)

    if @questao.save
      render json: @questao, status: :created, location: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /questaos/1
  def update
    if @questao.update(questao_params)
      render json: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # DELETE /questaos/1
  def destroy
    @questao.destroy!
  end

  # GET /questaos/count
  def count
    @questaos = apply_filters(Questao.all)
    render json: { count: @questaos.count }
  end

  # GET /questaos/ids
  def ids
    @questaos = apply_filters(Questao.all)
    render json: { ids: @questaos.pluck(:id) }
  end

  # GET /questaos/filters_page_questaos
  def filters_questaos
    @questaos = apply_filters(Questao.all)

    total_count = @questaos.count
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    @questaos = @questaos.offset((page - 1) * per_page).limit(per_page)

    render json: { questoes: @questaos, total_count: total_count }
  end

  private

  def set_questao
    @questao = Questao.find_by!(id: params[:id])
  end

  def apply_filters(scope)
    questaos = scope

    if params[:bancas].present?
      questaos = questaos.joins(:concurso).where(concursos: { banca_id: params[:bancas] })
    end

    if params[:orgaos].present?
      questaos = questaos.joins(:concurso).where(concursos: { orgao_id: params[:orgaos] })
    end

    if params[:ano].present?
      if params[:ano].to_s.include?('-')
        start_year, end_year = params[:ano].split('-').map(&:to_i)
        questaos = questaos.where(ano: start_year..end_year)
      else
        questaos = questaos.where(ano: params[:ano])
      end
    end

    if params[:escolaridade].present?
      questaos = questaos.where(id: ProvaQuestao.joins(:prova).where(provas: { escolaridade: params[:escolaridade] }).select(:questao_id))
    end

    if params[:assuntos].present?
      questaos = questaos.where(assunto_id: params[:assuntos])
    end

    if params[:disciplinas].present?
      questaos = questaos.where(disciplina_id: params[:disciplinas])
    end

    if params[:remover_anuladas] == 'true'
      questaos = questaos.where(anulada: nil)
    end

    if params[:remover_desatualizadas] == 'true'
      questaos = questaos.where(desatualizada: nil)
    end

    if params[:search].present?
      questaos = questaos.where('enunciado ILIKE ?', "%#{params[:search]}%")
    end

    questaos
  end

  def questao_params
    params.require(:questao).permit(
      :texto, :enunciado, :discursiva, :ano, :correta,
      :concurso_id, :assunto_id, :disciplina_id,
      :validado_admin, :sistema_ref_id,
      alternativas: [:value, :text]
    )
  end
end
