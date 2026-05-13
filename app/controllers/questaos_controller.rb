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

    total_count = questaos.count
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
      "COUNT(*) FILTER (WHERE disciplina_id IS NOT NULL AND assunto_id IS NOT NULL) as with_disciplina_assunto",
      "COUNT(*) FILTER (WHERE validado_admin IS NOT NULL) as validated"
    ).take

    by_year = scope.where.not(ano: nil).group(:ano).count.sort.to_h

    render_data = {
      total_count: stats_data.total || 0,
      with_correct_answer_count: stats_data.with_correct || 0,
      with_disciplina_count: stats_data.with_disciplina || 0,
      with_assunto_count: stats_data.with_assunto || 0,
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
