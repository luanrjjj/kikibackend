class ResolucoesController < ApplicationController
  before_action :authenticate_admin!, only: %i[ index global_stats ]

  def index
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [params.fetch(:per_page, 20).to_i, 1].max

    resolucoes = Resolucao.includes(:user, :questao, :caderno)
                          .order(created_at: :desc)
                          .offset((page - 1) * per_page)
                          .limit(per_page)

    render json: {
      data: resolucoes.as_json(include: {
        user: { only: [:id, :email, :name] },
        questao: { only: [:id, :enunciado] },
        caderno: { only: [:id, :nome] }
      }),
      meta: {
        current_page: page,
        per_page: per_page,
        total_count: Resolucao.count,
        total_pages: (Resolucao.count.to_f / per_page).ceil
      }
    }
  end

  def global_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
    
    query = <<-SQL
      SELECT 
        created_at::date as date,
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE created_at >= :start_date
      GROUP BY date
      ORDER BY date DESC
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { start_date: days.days.ago }])
    ).to_a

    summary_query = <<-SQL
      SELECT 
        count(*) as total,
        sum(case when correta then 1 else 0 end) as acertos,
        sum(case when not correta then 1 else 0 end) as erros,
        count(DISTINCT user_id) as total_usuarios
      FROM resolucaos
      WHERE created_at >= :start_date
    SQL

    summary_data = Resolucao.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([summary_query, { start_date: days.days.ago }])
    ).transform_values(&:to_i)

    render json: {
      daily_stats: stats,
      summary: summary_data
    }
  end

  def create
    @questao = Questao.find_by!(id: params[:resolucao][:questao_id])

    # Limit check for free users
    unless current_user.subscribed?
      limit = ConfigGlobalApolo.get('limit_resolutions_free', 10).to_i
      if current_user.resolucoes.count >= limit
        render json: { 
          error: 'limit_reached', 
          message: 'Você atingiu o limite de questões para o plano gratuito. Assine um plano pago para continuar.' 
        }, status: :forbidden
        return
      end
    end

    is_correct = @questao.correta == params[:resolucao][:resposta]

    @resolucao = current_user.resolucoes.new(resolucao_params)
    @resolucao.correta = is_correct

    if @resolucao.save
      render json: {
        resolucao: @resolucao,
        correta: is_correct,
        resposta_correta: @questao.correta
      }, status: :created
    else
      render json: @resolucao.errors, status: :unprocessable_entity
    end
  end

  def stats
    start_date, end_date = calculate_date_range
    
    query = <<-SQL
      SELECT 
        created_at::date as date,
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id 
        AND created_at >= :start_date
        AND created_at <= :end_date
      GROUP BY date
      ORDER BY date DESC
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: start_date, end_date: end_date }])
    ).to_a
    render json: stats
  end

  def discipline_stats
    start_date, end_date = calculate_date_range

    query = <<-SQL
      SELECT 
        d.nome as disciplina_nome,
        d.id as disciplina_id,
        count(r.*) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      WHERE r.user_id = :user_id 
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
      GROUP BY d.nome, d.id
      ORDER BY total_resolucoes DESC
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: start_date, end_date: end_date }])
    ).to_a
    render json: stats
  end

  def subject_stats
    start_date, end_date = calculate_date_range
    disciplina_id = params[:disciplina_id]

    sql_parts = [
      "SELECT 
        COALESCE(a.nome, 'Sem Assunto') as assunto_nome,
        count(r.*) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      WHERE r.user_id = :user_id 
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date",
      { user_id: current_user.id, start_date: start_date, end_date: end_date }
    ]

    if disciplina_id.present?
      sql_parts[0] += " AND q.disciplina_id = :disciplina_id"
      sql_parts[1][:disciplina_id] = disciplina_id
    end

    sql_parts[0] += " GROUP BY COALESCE(a.nome, 'Sem Assunto') ORDER BY total_resolucoes DESC"

    query = ActiveRecord::Base.sanitize_sql_array(sql_parts)
    stats = Resolucao.connection.select_all(query).to_a
    render json: stats
  end

  def hierarchical_stats
    unless current_user.admin? || current_user.variaveis['show_stats_table_by_assunto_basic']
      return render json: { error: 'permission_denied', message: 'Assine um plano para visualizar estatísticas detalhadas.' }, status: :forbidden
    end

    start_date, end_date = calculate_date_range

    query = <<-SQL
      SELECT 
        d.id as disciplina_id, d.nome as disciplina_nome,
        a.id as assunto_id, a.nome as assunto_nome,
        t.id as topico_id, t.nome as topico_nome,
        count(r.id) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      LEFT JOIN topicos t ON q.topico_id = t.id
      WHERE r.user_id = :user_id 
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
      GROUP BY d.id, d.nome, a.id, a.nome, t.id, t.nome
      ORDER BY d.nome, a.nome, t.nome
    SQL

    results = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: start_date, end_date: end_date }])
    ).to_a

    # Process results into hierarchy
    disciplinas_map = {}
    
    results.each do |row|
      d_id = row['disciplina_id']
      a_id = row['assunto_id']
      t_id = row['topico_id']

      d = disciplinas_map[d_id] ||= { 
        id: d_id, name: row['disciplina_nome'], 
        total_resolucoes: 0, 
        acertos: 0, 
        erros: 0,
        assuntos: {} 
      }
      
      d[:total_resolucoes] += row['total_resolucoes'].to_i
      d[:acertos] += row['total_acertos'].to_i
      d[:erros] += row['total_erros'].to_i

      assunto_id = a_id || "sem-assunto-#{d_id}"
      assunto_nome = row['assunto_nome'] || "Sem Assunto"

      a = d[:assuntos][assunto_id] ||= { 
        id: assunto_id, name: assunto_nome, 
        total_resolucoes: 0, 
        acertos: 0, 
        erros: 0,
        topicos: {}
      }
      a[:total_resolucoes] += row['total_resolucoes'].to_i
      a[:acertos] += row['total_acertos'].to_i
      a[:erros] += row['total_erros'].to_i

      if t_id.present?
        t = a[:topicos][t_id] ||= {
          id: t_id,
          name: row['topico_nome'] || "Tópico ##{t_id}",
          total_resolucoes: 0,
          acertos: 0,
          erros: 0
        }
        t[:total_resolucoes] += row['total_resolucoes'].to_i
        t[:acertos] += row['total_acertos'].to_i
        t[:erros] += row['total_erros'].to_i
      end
    end

    formatted_hierarchy = disciplinas_map.values.map do |d|
      {
        id: d[:id],
        name: d[:name],
        total_resolucoes: d[:total_resolucoes],
        acertos: d[:acertos],
        erros: d[:erros],
        assuntos: d[:assuntos].values.map do |a|
          {
            id: a[:id],
            name: a[:name],
            total_resolucoes: a[:total_resolucoes],
            acertos: a[:acertos],
            erros: a[:erros],
            topicos: a[:topicos].values.sort_by { |t| (t[:total_resolucoes] > 0 ? t[:acertos].to_f / t[:total_resolucoes] : 0) }.reverse
          }
        end.sort_by { |a| (a[:total_resolucoes] > 0 ? a[:acertos].to_f / a[:total_resolucoes] : 0) }.reverse
      }
    end.sort_by { |d| (d[:total_resolucoes] > 0 ? d[:acertos].to_f / d[:total_resolucoes] : 0) }.reverse

    render json: formatted_hierarchy
  end

  def gerar_caderno_stats
    unless current_user.admin? || current_user.variaveis['create_notebook_basic']
      return render json: { error: 'permission_denied', message: 'Assine um plano para criar seus próprios cadernos personalizados.' }, status: :forbidden
    end

    disciplina_ids = Array(params[:disciplina_ids]).map(&:to_i).reject(&:zero?)
    assunto_ids = Array(params[:assunto_ids]).map(&:to_s).reject(&:blank?)
    topico_ids = Array(params[:topico_ids]).map(&:to_i).reject(&:zero?)
    only_errors = ActiveModel::Type::Boolean.new.cast(params[:only_errors])

    clean_assunto_ids = assunto_ids.reject { |id| id.start_with?('sem-assunto-') }.map(&:to_i).reject(&:zero?)

    if disciplina_ids.empty? && clean_assunto_ids.empty? && topico_ids.empty?
      return render json: { error: 'invalid_params', message: 'Selecione ao menos um tópico ou matéria.' }, status: :unprocessable_entity
    end

    questaos = Questao.all

    classificacoes_filters = []
    classificacoes_filters += disciplina_ids.map { |id| "d_#{id}" } if disciplina_ids.present?
    classificacoes_filters += clean_assunto_ids.map { |id| "a_#{id}" } if clean_assunto_ids.present?
    classificacoes_filters += topico_ids.map { |id| "t_#{id}" } if topico_ids.present?

    or_clauses = []
    or_clauses << "classificacoes && ?" if classificacoes_filters.present?
    or_clauses << "questaos.disciplina_id IN (?)" if disciplina_ids.present?
    or_clauses << "questaos.assunto_id IN (?)" if clean_assunto_ids.present?
    or_clauses << "questaos.topico_id IN (?)" if topico_ids.present?

    clause_args = []
    clause_args << "{#{classificacoes_filters.join(',')}}" if classificacoes_filters.present?
    clause_args << disciplina_ids if disciplina_ids.present?
    clause_args << clean_assunto_ids if clean_assunto_ids.present?
    clause_args << topico_ids if topico_ids.present?

    questaos = questaos.where(or_clauses.join(' OR '), *clause_args) if or_clauses.present?

    if only_errors
      questaos = questaos.joins(:resolucoes)
                         .where(resolucaos: { user_id: current_user.id, correta: false })
      if params[:start_date].present? || params[:days].present?
        start_date, end_date = calculate_date_range
        questaos = questaos.where(resolucaos: { created_at: start_date..end_date })
      end
    end

    ids = questaos.distinct.pluck(:id)

    if ids.empty?
      msg = only_errors ? 'Nenhuma questão errada encontrada para os tópicos selecionados.' : 'Nenhuma questão encontrada para os tópicos selecionados.'
      return render json: { error: 'no_questions', message: msg }, status: :unprocessable_entity
    end

    max_limit = current_user.variaveis['max_caderno_questoes'].to_i
    max_limit = 10_000 if max_limit <= 0

    if ids.length > max_limit
      return render json: {
        error: 'max_caderno_questoes_exceeded',
        message: "Excedeu a quantidade máxima de #{max_limit} questões permitidas por caderno.",
        max_caderno_questoes: max_limit,
        questoes_count: ids.length
      }, status: :unprocessable_entity
    end

    # Pasta "Estatística"
    pasta = current_user.pasta_cadernos.where('LOWER(nome) = ?', 'estatística').first ||
            current_user.pasta_cadernos.create!(nome: 'Estatística')

    tipo_label = only_errors ? 'Erros' : 'Revisão'
    timestamp = Time.current.strftime('%d/%m/%Y %H:%M')
    default_nome = params[:caderno_nome].presence || "Estatísticas - #{tipo_label} (#{timestamp})"

    caderno = current_user.cadernos.create!(
      nome: default_nome,
      pasta_caderno_id: pasta.id,
      questoes_ids: ids,
      filtros: {
        origem: 'estatisticas',
        only_errors: only_errors,
        disciplina_ids: disciplina_ids,
        assunto_ids: clean_assunto_ids,
        topico_ids: topico_ids,
        questoes_count: ids.length
      }
    )

    render json: {
      id: caderno.id,
      nome: caderno.nome,
      pasta_id: pasta.id,
      pasta_nome: pasta.nome,
      questoes_count: ids.length,
      message: "Caderno criado com sucesso com #{ids.length} questões na pasta #{pasta.nome}!"
    }, status: :created
  end

  def export_excel_stats
    unless current_user.admin? || current_user.variaveis['excel_stats_export_advanced']
      return render json: { error: 'permission_denied', message: 'Assine um plano para exportar estatísticas para Excel.' }, status: :forbidden
    end

    render json: { status: 'ok', message: 'Permissão concedida para exportação.' }
  end

  def notebook_stats
    caderno_id = params[:caderno_id]
    return render json: { error: "Caderno ID is required" }, status: :bad_request if caderno_id.blank?

    caderno = Caderno.find_by(id: caderno_id)
    return render json: { error: "Caderno not found" }, status: :not_found unless caderno

    questao_ids = caderno.questoes_ids || []
    return render json: { summary: {}, hierarchy: [] } if questao_ids.empty?

    # Global notebook stats
    summary_query = <<-SQL
      SELECT 
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id 
        AND caderno_id = :caderno_id
    SQL

    summary = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([summary_query, { user_id: current_user.id, caderno_id: caderno_id }])
    ).first

    # Hierarchical stats based on latest resolution for each question
    hierarchy_query = <<-SQL
      WITH latest_resolutions AS (
        SELECT DISTINCT ON (questao_id)
          id, correta, questao_id
        FROM resolucaos
        WHERE user_id = :user_id AND caderno_id = :caderno_id
        ORDER BY questao_id, created_at DESC
      )
      SELECT 
        d.id as disciplina_id, d.nome as disciplina_nome,
        a.id as assunto_id, a.nome as assunto_nome,
        t.id as topico_id, t.nome as topico_nome,
        q.id as questao_id,
        lr.id as resolucao_id,
        lr.correta as correta
      FROM questaos q
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      LEFT JOIN topicos t ON q.topico_id = t.id
      LEFT JOIN latest_resolutions lr ON lr.questao_id = q.id
      WHERE q.id IN (:questao_ids)
    SQL

    results = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([hierarchy_query, { user_id: current_user.id, caderno_id: caderno_id, questao_ids: questao_ids }])
    ).to_a

    # Process results into hierarchy
    disciplinas_map = {}
    resolvidas_ids = []
    
    results.each do |row|
      d_id = row['disciplina_id']
      a_id = row['assunto_id']
      t_id = row['topico_id']
      q_id = row['questao_id']
      res_correta = row['correta']
      has_res = !row['resolucao_id'].nil?

      resolvidas_ids << q_id.to_i if has_res

      d = disciplinas_map[d_id] ||= { 
        id: d_id, name: row['disciplina_nome'], 
        total_questoes_ids: Set.new, 
        resolvidas_ids: Set.new, 
        acertos_ids: Set.new,
        assuntos: {} 
      }
      d[:total_questoes_ids] << q_id
      if has_res
        d[:resolvidas_ids] << q_id
        d[:acertos_ids] << q_id if res_correta
      end

      assunto_id = a_id || "sem-assunto-#{d_id}"
      assunto_nome = row['assunto_nome'] || "Sem Assunto"

      a = d[:assuntos][assunto_id] ||= { 
        id: assunto_id, name: assunto_nome, 
        total_questoes_ids: Set.new, 
        resolvidas_ids: Set.new, 
        acertos_ids: Set.new,
        topicos: {} 
      }
      a[:total_questoes_ids] << q_id
      if has_res
        a[:resolvidas_ids] << q_id
        a[:acertos_ids] << q_id if res_correta
      end

      if t_id
        t = a[:topicos][t_id] ||= { 
          id: t_id, name: row['topico_nome'], 
          total_questoes_ids: Set.new, 
          resolvidas_ids: Set.new, 
          acertos_ids: Set.new 
        }
        t[:total_questoes_ids] << q_id
        if has_res
          t[:resolvidas_ids] << q_id
          t[:acertos_ids] << q_id if res_correta
        end
      end
    end

    formatted_hierarchy = disciplinas_map.values.map do |d|
      {
        id: d[:id],
        name: d[:name],
        total_questoes: d[:total_questoes_ids].size,
        total_resolvidas: d[:resolvidas_ids].size,
        acertos: d[:acertos_ids].size,
        erros: d[:resolvidas_ids].size - d[:acertos_ids].size,
        assuntos: d[:assuntos].values.map do |a|
          {
            id: a[:id],
            name: a[:name],
            total_questoes: a[:total_questoes_ids].size,
            total_resolvidas: a[:resolvidas_ids].size,
            acertos: a[:acertos_ids].size,
            erros: a[:resolvidas_ids].size - a[:acertos_ids].size,
            questao_ids: a[:total_questoes_ids].to_a,
            topicos: a[:topicos].values.map do |t|
              {
                id: t[:id],
                name: t[:name],
                total_questoes: t[:total_questoes_ids].size,
                total_resolvidas: t[:resolvidas_ids].size,
                acertos: t[:acertos_ids].size,
                erros: t[:resolvidas_ids].size - t[:acertos_ids].size,
                questao_ids: t[:total_questoes_ids].to_a
              }
            end.sort_by { |t| t[:name] }
          }
        end.sort_by { |a| a[:name] }
      }
    end.sort_by { |d| d[:name] }

    render json: {
      summary: summary,
      hierarchy: formatted_hierarchy,
      resolvidas_ids: resolvidas_ids
    }
  end

  def question_stats
    questao_id = params[:questao_id]
    return render json: { error: "Questao ID is required" }, status: :bad_request if questao_id.blank?

    global_query = <<-SQL
      SELECT 
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros,
        count(DISTINCT user_id) as total_users
      FROM resolucaos
      WHERE questao_id = :questao_id
    SQL

    global_stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([global_query, { questao_id: questao_id }])
    ).first

    personal_query = <<-SQL
      SELECT 
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE questao_id = :questao_id AND user_id = :user_id
    SQL

    personal_stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([personal_query, { questao_id: questao_id, user_id: current_user.id }])
    ).first

    history = current_user.resolucoes
                          .where(questao_id: questao_id)
                          .order(created_at: :desc)
                          .select(:id, :resposta, :correta, :created_at)

    render json: {
      global: global_stats,
      personal: personal_stats,
      history: history
    }
  end

  private

  def calculate_date_range
    if params[:start_date].present? && params[:end_date].present?
      [params[:start_date].to_date.beginning_of_day, params[:end_date].to_date.end_of_day]
    else
      days = params[:days].to_i > 0 ? params[:days].to_i : 30
      [days.days.ago.beginning_of_day, Time.current.end_of_day]
    end
  end

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
