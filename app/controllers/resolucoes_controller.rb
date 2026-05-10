class ResolucoesController < ApplicationController
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
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
    
    query = <<-SQL
      SELECT 
        created_at::date as date,
        count(*) as total_resolucoes,
        sum(case when correta then 1 else 0 end) as total_acertos,
        sum(case when not correta then 1 else 0 end) as total_erros
      FROM resolucaos
      WHERE user_id = :user_id 
        AND created_at >= :start_date
      GROUP BY date
      ORDER BY date DESC
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: days.days.ago }])
    ).to_a
    render json: stats
  end

  def discipline_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30

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
      GROUP BY d.nome, d.id
      ORDER BY total_resolucoes DESC
    SQL

    stats = Resolucao.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([query, { user_id: current_user.id, start_date: days.days.ago }])
    ).to_a
    render json: stats
  end

  def subject_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
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
        AND r.created_at >= :start_date",
      { user_id: current_user.id, start_date: days.days.ago }
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

  private

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
