require 'digest'

class QuestaosController < ApplicationController
  before_action :authenticate_subscription, only: %i[ filters_questaos ]
  before_action :set_questao, only: %i[ show update destroy validate anotacao save_anotacao explicacao_ia avaliar_explicacao_ia ]
  before_action :authenticate_user!, only: %i[ anotacao save_anotacao explicacao_ia avaliar_explicacao_ia ]
  before_action :authenticate_admin!, only: %i[ index stats origens_classificacao validate ]

  # GET /questaos
  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    # Fetch from PostgreSQL
    questaos = Questao.all

    if params[:questao_id].present? || (params[:id].present? && params[:id].to_s.match?(/\A\d+\z/))
      q_id = (params[:questao_id] || params[:id]).to_i
      questaos = questaos.where("questaos.id = ?", q_id)
    end

    if params[:disciplina_id].present?
      questaos = questaos.where(disciplina_id: params[:disciplina_id].to_i)
    end

    if params[:prova_id].present?
      questaos = questaos.joins(:prova_questaos).where(prova_questaos: { prova_id: params[:prova_id].to_i })
    end

    if params[:assunto_id].present?
      questaos = questaos.where(assunto_id: params[:assunto_id].to_i)
    end

    if params[:topico_id].present?
      questaos = questaos.where(topico_id: params[:topico_id].to_i)
    end

    if params[:classificacao_origem].present? || params[:classificao_origem].present?
      val = params[:classificacao_origem].presence || params[:classificao_origem].presence
      origem_col = if Questao.column_names.include?('classificacao_origem')
                     'questaos.classificacao_origem'
                   elsif Questao.column_names.include?('classificao_origem')
                     'questaos.classificao_origem'
                   end
      questaos = questaos.where("#{origem_col} ILIKE ?", "%#{val}%") if origem_col
    end

    if ActiveModel::Type::Boolean.new.cast(params[:com_text_to_verify])
      questaos = questaos.where.not(text_to_verify: nil)
    end

    questaos = apply_search_filter(questaos, params[:search])

    # Cache the total count based on the query SQL to avoid slow COUNT(*) on large tables
    cache_key = "admin/questaos/count/#{Digest::SHA256.hexdigest(questaos.to_sql)}"
    total_count = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      questaos.count
    end

    questaos_data = questaos.includes(:disciplina, :assunto, :topico, :provas, :texto, :texto_para_verificar, concurso: [:banca, :orgao])
                            .order("questaos.id ASC")
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
    has_filters = params[:disciplina_id].present? || params[:assunto_id].present? || params[:topico_id].present? || params[:prova_id].present? || params[:search].present? || params[:classificacao_origem].present? || params[:classificao_origem].present? || params[:questao_id].present?

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

    if params[:questao_id].present? || (params[:id].present? && params[:id].to_s.match?(/\A\d+\z/))
      q_id = (params[:questao_id] || params[:id]).to_i
      scope = scope.where("questaos.id = ?", q_id)
    end

    scope = scope.where(disciplina_id: params[:disciplina_id]) if params[:disciplina_id].present?
    scope = scope.where(assunto_id: params[:assunto_id]) if params[:assunto_id].present?
    scope = scope.where(topico_id: params[:topico_id]) if params[:topico_id].present?

    if params[:classificacao_origem].present? || params[:classificao_origem].present?
      val = params[:classificacao_origem].presence || params[:classificao_origem].presence
      origem_col = if Questao.column_names.include?('classificacao_origem')
                     'questaos.classificacao_origem'
                   elsif Questao.column_names.include?('classificao_origem')
                     'questaos.classificao_origem'
                   end
      scope = scope.where("#{origem_col} ILIKE ?", "%#{val}%") if origem_col
    end

    if params[:prova_id].present?
      scope = scope.joins(:prova_questaos).where(prova_questaos: { prova_id: params[:prova_id] })
    end

    scope = apply_search_filter(scope, params[:search])

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

  # GET /questaos/origens_classificacao
  def origens_classificacao
    cache_key = "admin/questaos/origens_classificacao"
    origens = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      col = if Questao.column_names.include?('classificacao_origem')
              :classificacao_origem
            elsif Questao.column_names.include?('classificao_origem')
              :classificao_origem
            end

      if col
        Questao.where.not(col => [nil, ""])
               .distinct
               .order(col)
               .pluck(col)
      else
        []
      end
    end

    render json: origens || []
  rescue => e
    Rails.logger.error "[QuestaosController#origens_classificacao] Error: #{e.message}"
    render json: []
  end

  # PATCH /questaos/:id/validate
  # Marca a questão como validada pelo admin. Se ela tiver um texto p/ verificar
  # (text_to_verify), esse texto passa a ser o texto da questão (texto_id).
  # O text_to_verify é mantido para histórico.
  def validate
    attrs = { validado_admin: Time.current }
    attrs[:texto_id] = @questao.text_to_verify if @questao.text_to_verify.present?

    if @questao.update(attrs)
      render json: @questao
    else
      render json: @questao.errors, status: :unprocessable_entity
    end
  end

  # GET /questaos/1
  def show
    resolucoes = nil
    if params[:caderno_id].present? && current_user
      resolucoes = current_user.resolucoes.where(caderno_id: params[:caderno_id], questao_id: @questao.id).order(:created_at).index_by { |r| r[:questao_id] }
    end

    render json: QuestaoSerializer.new(@questao, {
      params: {
        resolucoes: resolucoes
      }
    }).serializable_hash
  end

  # POST /questaos/1/explicacao_ia   { provedor: "deepseek", regenerar: false }
  # Explicação da questão por IA (kikiapps#22). Se já existe uma salva em
  # questaos.deepseek_explicacao, devolve ela sem chamar a IA.
  # regenerar=true só vale para admin.
  def explicacao_ia
    servico = ExplicacaoIaService.new(@questao, user: current_user, provedor: params[:provedor])
    render json: servico.call(regenerar: ActiveModel::Type::Boolean.new.cast(params[:regenerar]) == true)
  rescue ExplicacaoIaService::Erro => e
    render json: { error: e.message }, status: e.status
  end

  # POST /questaos/1/explicacao_ia/avaliacao   { provedor: "deepseek", util: true }
  def avaliar_explicacao_ia
    servico = ExplicacaoIaService.new(@questao, user: current_user, provedor: params[:provedor])
    render json: servico.avaliar!(params[:util])
  rescue ExplicacaoIaService::Erro => e
    render json: { error: e.message }, status: e.status
  end

  # GET /questaos/1/anotacao
  def anotacao
    anotacao = current_user.anotacaos.find_by(questao_id: @questao.id)
    render json: { texto: anotacao&.texto || "" }
  end

  # POST /questaos/1/anotacao
  def save_anotacao
    anotacao = current_user.anotacaos.find_or_initialize_by(questao_id: @questao.id)
    anotacao.texto = params[:texto]
    
    if anotacao.texto.blank?
      anotacao.destroy if anotacao.persisted?
      render json: { texto: "" }
    elsif anotacao.save
      render json: { texto: anotacao.texto }
    else
      render json: { errors: anotacao.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /questaos
  def create
    attrs = questao_params.to_h
    texto_content = attrs.delete('texto')

    if attrs['texto_id'].present?
      attrs['texto_id'] = attrs['texto_id'].to_i
    elsif texto_content.present?
      p_id = attrs['prova_id']
      c_id = attrs['concurso_id']
      new_texto = Texto.create(
        texto: texto_content,
        prova_id: p_id,
        concurso_id: c_id
      )
      attrs['texto_id'] = new_texto.id if new_texto.persisted?
    end

    @questao = Questao.new(attrs)

    if @questao.save
      render json: @questao, status: :created, location: @questao
    else
      render_validation_errors(@questao, "Erro ao criar questão")
    end
  end

  # PATCH/PUT /questaos/1
  def update
    attrs = questao_params.to_h
    texto_content = attrs.delete('texto')

    if attrs['texto_id'].present?
      attrs['texto_id'] = attrs['texto_id'].to_i
      unless Texto.exists?(id: attrs['texto_id'])
        return render json: { error: "Texto não encontrado", message: "Texto ##{attrs['texto_id']} não existe." }, status: :unprocessable_entity
      end
    elsif texto_content.present?
      if @questao.texto.present?
        @questao.texto.update(texto: texto_content)
      else
        p_id = attrs['prova_id'] || @questao.prova_questaos.first&.prova_id
        c_id = attrs['concurso_id'] || @questao.concurso_id
        new_texto = Texto.create(
          texto: texto_content,
          prova_id: p_id,
          concurso_id: c_id
        )
        attrs['texto_id'] = new_texto.id if new_texto.persisted?
      end
    elsif attrs.key?('texto_id') && attrs['texto_id'].blank?
      attrs['texto_id'] = nil
    end

    if @questao.update(attrs)
      render json: @questao
    else
      render_validation_errors(@questao, "Erro ao atualizar questão")
    end
  end

  # DELETE /questaos/1
  def destroy
    @questao.destroy!
  end

  # GET /questaos/count
  def count
    @questaos = apply_filters(Questao.all)

    cache_key = filtros_cache_key('count')

    count_val = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      com_timeout { @questaos.count }
    end

    render json: { count: count_val }
  rescue ActiveRecord::QueryCanceled
    render_filtro_muito_amplo
  end

  # GET /questaos/ids
  # Devolve no máximo o limite de questões por caderno do usuário. Antes, um
  # filtro amplo (ex.: só a banca Cespe/Cebraspe, ~300 mil questões) fazia
  # pluck de tudo, cacheava e mandava megabytes de IDs para o navegador, que
  # ainda os reenviava ao criar o caderno — só para serem recusados pelo limite.
  def ids
    @questaos = apply_filters(Questao.all)

    max_limit = current_user&.variaveis.to_h['max_caderno_questoes'].to_i
    max_limit = 10_000 if max_limit <= 0

    cache_key = filtros_cache_key("ids/max#{max_limit}")
    ids_val = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      # Busca um a mais para saber se passou do limite sem contar a tabela toda
      com_timeout { @questaos.limit(max_limit + 1).pluck(:id) }
    end

    if ids_val.size > max_limit
      total = Rails.cache.fetch(filtros_cache_key('count'), expires_in: 30.minutes) { com_timeout { @questaos.count } }
      return render json: {
        error: 'max_caderno_questoes_exceeded',
        message: "Os filtros retornam #{total} questões; o máximo por caderno é #{max_limit}.",
        max_caderno_questoes: max_limit,
        questoes_count: total
      }, status: :unprocessable_entity
    end

    render json: { ids: ids_val }
  rescue ActiveRecord::QueryCanceled
    render_filtro_muito_amplo
  end

  # GET /questaos/filters_page_questaos
  def filters_questaos
    @questaos = apply_filters(Questao.all)

    cache_key = filtros_cache_key('count')
    total_count = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      com_timeout { @questaos.count }
    end

    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 10
    @questaos = @questaos.offset((page - 1) * per_page).limit(per_page)

    render json: { questoes: @questaos, total_count: total_count }
  end

  private

  FILTRO_STATEMENT_TIMEOUT = ENV.fetch('FILTRO_STATEMENT_TIMEOUT', '20s')

  # Limita o tempo das consultas de filtro no Postgres: uma consulta muito
  # ampla não pode segurar uma thread do Puma e o banco indefinidamente.
  def com_timeout
    Questao.transaction do
      Questao.connection.execute("SET LOCAL statement_timeout = #{Questao.connection.quote(FILTRO_STATEMENT_TIMEOUT)}")
      yield
    end
  end

  def render_filtro_muito_amplo
    render json: {
      error: 'filtro_muito_amplo',
      message: 'Esse filtro retorna questões demais para calcular agora. Adicione mais um filtro (ex.: disciplina ou ano) e tente de novo.'
    }, status: :service_unavailable
  end

  # Chave de cache estável entre processos para os endpoints de filtro.
  # String#hash do Ruby é aleatório por processo, então a chave antiga quase
  # nunca reaproveitava o cache entre workers/restarts.
  def filtros_cache_key(prefixo)
    relevantes = params.to_unsafe_h.except('controller', 'action', 'format', 'page', 'per_page')
    normalizados = relevantes.sort.map { |k, v| [k, v.is_a?(Array) ? v.map(&:to_s).sort : v.to_s] }
    "questaos/#{prefixo}/v3/#{Digest::SHA256.hexdigest(normalizados.to_json)}"
  end

  def set_questao
    @questao = Questao.find_by!(id: params[:id])
  end

  def apply_filters(scope)
    filter_params = params.to_unsafe_h.slice(*QuestaoFilterService::FILTER_KEYS, 'remover_anuladas', 'remover_desatualizadas')
    questaos = QuestaoFilterService.apply(scope, filter_params)

    if params[:classificacao_origem].present? || params[:classificao_origem].present?
      val = params[:classificacao_origem].presence || params[:classificao_origem].presence
      origem_col = if Questao.column_names.include?('classificacao_origem')
                     'questaos.classificacao_origem'
                   elsif Questao.column_names.include?('classificao_origem')
                     'questaos.classificao_origem'
                   end
      questaos = questaos.where("#{origem_col} ILIKE ?", "%#{val}%") if origem_col
    end

    if params[:questao_id].present? || (params[:id].present? && params[:id].to_s.match?(/\A\d+\z/))
      q_id = (params[:questao_id] || params[:id]).to_i
      questaos = questaos.where("questaos.id = ?", q_id)
    end

    questaos = apply_search_filter(questaos, params[:search])

    questaos
  end

  def apply_search_filter(scope, search_param)
    return scope if search_param.blank?

    search_str = search_param.to_s.strip
    return scope if search_str.blank?

    # 1. Direct ID search: "12345", "#12345", "id:12345", "ID: 12345"
    if search_str =~ /\A(?:id:\s*|#)?(\d+)\z/i
      target_id = $1.to_i
      return scope.where("questaos.id = ? OR questaos.sistema_ref_id = ?", target_id, search_str)
    end

    # 2. Direct Ref ID search: "Q12345", "ref: Q12345"
    if search_str =~ /\A(?:ref:\s*|#)?([A-Z]\d+)\z/i
      target_ref = $1
      return scope.where("questaos.sistema_ref_id = ?", target_ref)
    end

    # 3. Multi-word search
    keywords = search_str.split(/\s+/).reject(&:blank?)
    keywords.each do |kw|
      clean_kw = kw.tr('#', '')
      if clean_kw.match?(/\A\d+\z/)
        # Numeric word: search indexed id or sistema_ref_id directly
        scope = scope.where("questaos.id = ? OR questaos.sistema_ref_id = ?", clean_kw.to_i, kw)
      elsif clean_kw.match?(/\A[A-Z]\d+\z/i)
        # Ref word (e.g. Q12345): search indexed sistema_ref_id
        scope = scope.where("questaos.sistema_ref_id = ?", clean_kw)
      else
        # Text word: search enunciado or sistema_ref_id
        term = "%#{kw}%"
        scope = scope.where(
          "questaos.enunciado ILIKE ? OR questaos.sistema_ref_id ILIKE ?",
          term,
          term
        )
      end
    end

    scope
  end

  def questao_params
    params.require(:questao).permit(
      :texto_id, :texto, :enunciado, :discursiva, :ano, :correta,
      :concurso_id, :assunto_id, :disciplina_id, :topico_id,
      :validado_admin, :sistema_ref_id, :classificacao_origem, :classificao_origem,
      alternativas: [:value, :text]
    )
  end
end
