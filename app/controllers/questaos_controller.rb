class QuestaosController < ApplicationController
  before_action :authenticate_subscription, only: %i[ filters_questaos ]
  before_action :set_questao, only: %i[ show update destroy validate ]
  before_action :authenticate_admin!, only: %i[ index stats ]

  # GET /questaos
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    # Fetch from PostgreSQL
    questaos = Questao.all

    if params[:disciplina_id].present?
      questaos = questaos.where(disciplina_id: params[:disciplina_id].to_i)
    end

    if params[:prova_id].present?
      questaos = questaos.joins(:prova_questaos).where(prova_questaos: { prova_id: params[:prova_id].to_i })
    end

    if params[:assunto_id].present?
      questaos = questaos.where(assunto_id: params[:assunto_id].to_i)
    end

    if params[:search].present?
      questaos = questaos.where("enunciado ILIKE ?", "%#{params[:search]}%")
    end

    # Cache the total count based on the query SQL to avoid slow COUNT(*) on large tables
    cache_key = "admin/questaos/count/#{Digest::SHA256.hexdigest(questaos.to_sql)}"
    total_count = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      questaos.count
    end

    questaos_data = questaos.includes(:disciplina, :assunto, :provas, concurso: [:banca, :orgao])
                            .order(id: :asc)
                            .offset((page - 1) * per_page)
                            .limit(per_page)

    render json: {
      data: questaos_data,
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
    has_filters = params[:disciplina_id].present? || params[:assunto_id].present? || params[:prova_id].present? || params[:search].present?

    if !has_filters
      cached_stats = Rails.cache.read("admin/stats/questaos/global")
      if cached_stats
        Rails.logger.info "[Cache] Hit admin/stats/questaos/global"
        render json: cached_stats
        return
      else
        Rails.logger.info "[Cache] Miss admin/stats/questaos/global"
      end
    end

    # Fallback to PostgreSQL for filtered stats
    scope = Questao.all
    scope = scope.where(disciplina_id: params[:disciplina_id]) if params[:disciplina_id].present?
    scope = scope.where(assunto_id: params[:assunto_id]) if params[:assunto_id].present?
    scope = scope.where("enunciado ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    
    if params[:prova_id].present?
      scope = scope.joins(:prova_questaos).where(prova_questaos: { prova_id: params[:prova_id] })
    end

    stats_data = scope.select(
      "COUNT(*) as total",
      "COUNT(*) FILTER (WHERE correta IS NOT NULL AND correta != '') as with_correct",
      "COUNT(*) FILTER (WHERE disciplina_id IS NOT NULL) as with_disciplina",
      "COUNT(*) FILTER (WHERE assunto_id IS NOT NULL) as with_assunto",
      "COUNT(*) FILTER (WHERE topico_id IS NOT NULL) as with_topico",
      "COUNT(*) FILTER (WHERE disciplina_id IS NOT NULL AND assunto_id IS NOT NULL) as with_disciplina_assunto",
      "COUNT(*) FILTER (WHERE validado_admin IS NOT NULL) as validated"
    ).take

    by_year = scope.where.not(ano: nil).group(:ano).count.sort.to_h

    render_data = {
      total_count: stats_data.total || 0,
      with_correct_answer_count: stats_data.with_correct || 0,
      with_disciplina_count: stats_data.with_disciplina || 0,
      with_assunto_count: stats_data.with_assunto || 0,
      with_topico_count: stats_data.with_topico || 0,
      with_disciplina_assunto_count: stats_data.with_disciplina_assunto || 0,
      validated_count: stats_data.validated || 0,
      by_year: by_year,
      updated_at: Time.current
    }

    # Cache global results if no filters were applied
    Rails.cache.write("admin/stats/questaos/global", render_data) if !has_filters

    render json: render_data
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
    # If caderno_id is present, fetch user resolution for this question in this notebook
    resolucoes = nil
    if params[:caderno_id].present?
      resolucoes = current_user.resolucoes.where(caderno_id: params[:caderno_id], questao_id: @questao.id).index_by { |r| r[:questao_id] }
    end

    render json: QuestaoSerializer.new(@questao, { 
      params: { 
        resolucoes: resolucoes 
      } 
    }).serializable_hash
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
    
    # Use the generated SQL as part of the cache key
    # We use distinct.select(:id) to match the count query's structure
    sql_key = Digest::SHA256.hexdigest(@questaos.distinct.select(:id).to_sql)
    cache_key = "questaos/count/#{sql_key}"

    count_val = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      @questaos.distinct.count(:id)
    end

    render json: { count: count_val }
  end

  # GET /questaos/ids
  def ids
    @questaos = apply_filters(Questao.all)
    
    # Cache IDs as well, as this can be a large result
    sql_key = Digest::SHA256.hexdigest(@questaos.distinct.select(:id).to_sql)
    cache_key = "questaos/ids/#{sql_key}"

    ids_val = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      @questaos.distinct.pluck(:id)
    end

    render json: { ids: ids_val }
  end

  # GET /questaos/filters_page_questaos
  def filters_questaos
    @questaos = apply_filters(Questao.all)

    # Also cache total_count here
    sql_key = Digest::SHA256.hexdigest(@questaos.distinct.select(:id).to_sql)
    cache_key = "questaos/count/#{sql_key}"
    total_count = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      @questaos.distinct.count(:id)
    end

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

    # Consolidate joins to concursos
    if params[:bancas].present? || params[:orgaos].present?
      questaos = questaos.joins(:concurso)
      questaos = questaos.where(concursos: { banca_id: params[:bancas] }) if params[:bancas].present?
      questaos = questaos.where(concursos: { orgao_id: params[:orgaos] }) if params[:orgaos].present?
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
      # Use EXISTS which is often faster than IN (SELECT ...) in PostgreSQL
      questaos = questaos.where(
        "EXISTS (SELECT 1 FROM prova_questaos pq JOIN provas p ON pq.prova_id = p.id WHERE pq.questao_id = questaos.id AND p.escolaridade = ?)",
        params[:escolaridade]
      )
    end

    if params[:disciplinas].present? || params[:assuntos].present? || params[:topicos].present?
      conditions = []
      values = {}

      if params[:disciplinas].present?
        conditions << "disciplina_id IN (:disciplinas)"
        values[:disciplinas] = params[:disciplinas]
      end

      if params[:assuntos].present?
        conditions << "assunto_id IN (:assuntos)"
        values[:assuntos] = params[:assuntos]
      end

      if params[:topicos].present?
        conditions << "topico_id IN (:topicos)"
        values[:topicos] = params[:topicos]
      end

      if conditions.any?
        questaos = questaos.where(conditions.join(" OR "), values)
      end
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
      :concurso_id, :assunto_id, :disciplina_id, :topico_id,
      :validado_admin, :sistema_ref_id,
      alternativas: [:value, :text]
    )
  end
end
