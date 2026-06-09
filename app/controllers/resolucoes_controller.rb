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
        count(r.id) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN disciplinas d ON q.disciplina_id = d.id
      LEFT JOIN assuntos a ON q.assunto_id = a.id
      WHERE r.user_id = :user_id 
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date
      GROUP BY d.id, d.nome, a.id, a.nome
      ORDER BY d.nome, a.nome
    SQL

    results = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: start_date, end_date: end_date }])
    ).to_a

    # Process results into hierarchy
    disciplinas_map = {}
    
    results.each do |row|
      d_id = row['disciplina_id']
      a_id = row['assunto_id']

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
        topicos: []
      }
      a[:total_resolucoes] += row['total_resolucoes'].to_i
      a[:acertos] += row['total_acertos'].to_i
      a[:erros] += row['total_erros'].to_i
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
            topicos: []
          }
        end.sort_by { |a| (a[:total_resolucoes] > 0 ? a[:acertos].to_f / a[:total_resolucoes] : 0) }.reverse
      }
    end.sort_by { |d| (d[:total_resolucoes] > 0 ? d[:acertos].to_f / d[:total_resolucoes] : 0) }.reverse

    render json: formatted_hierarchy
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
