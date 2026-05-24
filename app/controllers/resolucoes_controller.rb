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
        user: { only: [:id, :email, :nome] },
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

    summary = Resolucao.select(
      "count(*) as total",
      "sum(case when correta then 1 else 0 end) as acertos",
      "sum(case when not correta then 1 else 0 end) as erros",
      "count(DISTINCT user_id) as total_usuarios"
    ).take

    render json: {
      daily_stats: stats,
      summary: summary
    }
  end

  def create
    @questao = Questao.find_by!(id: params[:resolucao][:questao_id])
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
        a.nome as assunto_nome,
        count(r.*) as total_resolucoes,
        sum(case when r.correta then 1 else 0 end) as total_acertos,
        sum(case when not r.correta then 1 else 0 end) as total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      JOIN assuntos a ON q.assunto_id = a.id
      WHERE r.user_id = :user_id 
        AND r.created_at >= :start_date
        AND r.created_at <= :end_date",
      { user_id: current_user.id, start_date: start_date, end_date: end_date }
    ]

    if disciplina_id.present?
      sql_parts[0] += " AND q.disciplina_id = :disciplina_id"
      sql_parts[1][:disciplina_id] = disciplina_id
    end

    sql_parts[0] += " GROUP BY a.nome ORDER BY total_resolucoes DESC"

    query = ActiveRecord::Base.sanitize_sql_array(sql_parts)
    stats = Resolucao.connection.select_all(query).to_a
    render json: stats
  end

  def notebook_stats
    caderno_id = params[:caderno_id]
    return render json: { error: "Caderno ID is required" }, status: :bad_request if caderno_id.blank?

    query = <<-SQL
      SELECT 
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id 
        AND caderno_id = :caderno_id
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, caderno_id: caderno_id }])
    ).first
    render json: stats
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

    render json: {
      global: global_stats,
      personal: personal_stats
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
