class ProvasController < ApplicationController
  before_action :authenticate_subscription, only: %i[ questaos ]
  before_action :set_prova, only: %i[ show update destroy questaos ]
  before_action :authenticate_admin!, only: %i[ index all stats years ]

  # GET /provas
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    @provas = Prova.includes(:orgao, :banca, :concurso)

    # Apply filters with multi-keyword fuzzy matching across prova ID, prova name, concurso, orgao and banca
    if params[:search].present?
      keywords = params[:search].to_s.strip.split(/\s+/).reject(&:blank?)
      if keywords.any?
        @provas = @provas.left_joins(:orgao, :banca, :concurso)
        keywords.each do |kw|
          clean_kw = kw.delete('#')
          term = "%#{kw}%"
          if clean_kw.match?(/\A\d+\z/)
            @provas = @provas.where(
              "provas.id = :id_val OR provas.nome ILIKE :term OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term, id_val: clean_kw.to_i
            )
          else
            @provas = @provas.where(
              "provas.nome ILIKE :term OR concursos.nome ILIKE :term OR orgaos.nome ILIKE :term OR orgaos.sigla ILIKE :term OR bancas.nome ILIKE :term OR bancas.sigla ILIKE :term",
              term: term
            )
          end
        end
      end
    end
    @provas = @provas.where(ano: params[:ano]) if params[:ano].present?
    @provas = @provas.where(banca_id: params[:banca_id]) if params[:banca_id].present?
    @provas = @provas.where(concurso_id: params[:concurso_id]) if params[:concurso_id].present?

    total_count = @provas.count
    @provas = @provas.order(ano: :desc, nome: :asc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

    prova_ids = @provas.map(&:id)
    questaos_counts = ProvaQuestao.where(prova_id: prova_ids).group(:prova_id).count

    provas_data = @provas.map do |prova|
      prova.as_json(prova_json_options).merge(
        total_questoes: questoes_counts[prova.id] || 0
      )
    end

    render json: {
      data: provas_data,
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def paginated_by_ano
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    @provas = Prova.includes(:orgao, :banca, :concurso)

    # Apply filters
    @provas = @provas.where("provas.nome ILIKE ?", "%#{params[:nome]}%") if params[:nome].present?

    if params[:concurso_nome].present?
      @provas = @provas.joins(:concurso).where("concursos.nome ILIKE ?", "%#{params[:concurso_nome]}%")
    end

    @provas = @provas.where(ano: params[:ano]) if params[:ano].present?
    @provas = @provas.where(banca_id: params[:banca_id]) if params[:banca_id].present?
    @provas = @provas.where(area_de_atuacao_id: params[:area_de_atuacao_id]) if params[:area_de_atuacao_id].present?
    @provas = @provas.where(area_de_formacao_id: params[:area_de_formacao_id]) if params[:area_de_formacao_id].present?

    total_count = @provas.count
    @provas = @provas.order(ano: :desc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

    render json: {
      data: @provas.as_json(prova_json_options),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  # GET /provas/all
  def all
    render json: Prova.select(:id, :nome).order(:nome)
  end

  # GET /provas/stats
  def stats
    has_filters = params[:ano].present? || params[:banca_id].present? || params[:search].present?

    if !has_filters
      cached_stats = Rails.cache.read("admin/stats/provas/global")
      if cached_stats
        Rails.logger.info "[Cache] Hit admin/stats/provas/global"
        render json: cached_stats
        return
      else
        Rails.logger.info "[Cache] Miss admin/stats/provas/global"
      end
    end

    @provas = Prova.all

    @provas = @provas.where(ano: params[:ano]) if params[:ano].present?
    @provas = @provas.where(banca_id: params[:banca_id]) if params[:banca_id].present?
    @provas = @provas.where("nome ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    total_count = @provas.count
    by_year = @provas.where.not(ano: nil).group(:ano).count.sort.to_h

    render_data = {
      total_count: total_count,
      by_year: by_year,
      updated_at: Time.current
    }

    # Cache global results if no filters were applied
    Rails.cache.write("admin/stats/provas/global", render_data) if !has_filters

    render json: render_data
  end

  # GET /provas/years
  def years
    render json: Prova.where.not(ano: nil).order(ano: :desc).distinct.pluck(:ano)
  end

  def popular
    limit = params.fetch(:limit, 5).to_i

    # Get the most popular prova_ids based on Caderno associations
    popular_counts = Caderno.where.not(prova_id: nil)
                            .group(:prova_id)
                            .order('count_all DESC')
                            .limit(limit)
                            .count

    popular_prova_ids = popular_counts.keys

    # Fetch the Prova records with their associations
    @provas = Prova.where(id: popular_prova_ids)
                   .includes(:orgao, :banca, :concurso)

    # To maintain the order from popular_prova_ids, we map manually
    ranked_provas = popular_prova_ids.map do |id|
      prova = @provas.find { |p| p.id == id }
      next nil unless prova

      prova.as_json(prova_json_options).merge(acessos: popular_counts[id])
    end.compact

    render json: ranked_provas
  end
  def questaos
    cache_key = "prova/#{@prova.id}/questaos/v4"

    json_data = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      prova_questaos = @prova.prova_questaos
                             .includes(questao: [:topico, :assunto, :disciplina, :texto, :concurso, :comentarios])
                             .order(:numero_questao)

      questaos = prova_questaos.map(&:questao).compact.uniq { |q| q.id }

      QuestaoSerializer.new(questaos, {
        params: {
          prova: @prova
        }
      }).serializable_hash
    end

    render json: json_data
  end

  # GET /provas/1
  def show
    stats = @prova.questaos
                  .left_joins(:disciplina, :assunto)
                  .group('disciplinas.nome', 'assuntos.nome')
                  .count

    summary = stats.each_with_object({}) do |((d_nome, a_nome), count), hash|
      disciplina = d_nome || "Sem Disciplina"
      assunto = a_nome || "Sem Assunto"
      hash[disciplina] ||= { total: 0, assuntos: [] }
      hash[disciplina][:total] += count
      hash[disciplina][:assuntos] << { nome: assunto, total: count }
    end

    render json: @prova.as_json(prova_json_options).merge(
      questaos_summary: {
        total: @prova.questaos.count,
        disciplinas: summary.map { |name, data| { nome: name, **data } }
      }
    )
  end

  # POST /provas
  def create
    @prova = Prova.new(prova_params)

    if @prova.save
      render json: @prova, status: :created, location: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /provas/1
  def update
    if @prova.update(prova_params)
      render json: @prova
    else
      render json: @prova.errors, status: :unprocessable_entity
    end
  end

  # DELETE /provas/1
  def destroy
    @prova.destroy!
  end

  private
    def set_prova
      @prova = Prova.find(params[:id])
    end

    def prova_params
      params.require(:prova).permit(:nome, :orgao_id, :banca_id, :concurso_id, :ano, :escolaridade, :pdfs_folder_url)
    end

    def prova_json_options
      {
        include: {
          orgao: { except: %i[created_at updated_at] },
          banca: { except: %i[created_at updated_at] },
          concurso: { except: %i[created_at updated_at validado_admin] }
        },
        except: %i[created_at updated_at validado_admin]
      }
    end
end