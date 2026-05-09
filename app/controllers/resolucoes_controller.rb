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
    
    query = ActiveRecord::Base.sanitize_sql_array([
      "SELECT 
        toDate(created_at) as date,
        count() as total_resolucoes,
        sum(correta) as total_acertos,
        count() - sum(correta) as total_erros
      FROM resolucaos
      WHERE user_id = ? 
        AND created_at >= now() - INTERVAL ? DAY
      GROUP BY date
      ORDER BY date DESC",
      current_user.id, days
    ])

    stats = ClickhouseSyncService.client.query(query).to_hashes
    render json: stats
  end

  def discipline_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30

    query = ActiveRecord::Base.sanitize_sql_array([
      "SELECT 
        disciplina_nome,
        disciplina_id,
        count() as total_resolucoes,
        sum(correta) as total_acertos,
        count() - sum(correta) as total_erros
      FROM resolucaos
      WHERE user_id = ? 
        AND created_at >= now() - INTERVAL ? DAY
      GROUP BY disciplina_nome, disciplina_id
      ORDER BY total_resolucoes DESC",
      current_user.id, days
    ])

    stats = ClickhouseSyncService.client.query(query).to_hashes
    render json: stats
  end

  def subject_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
    disciplina_id = params[:disciplina_id]

    sql_parts = [
      "SELECT 
        assunto_nome,
        count() as total_resolucoes,
        sum(correta) as total_acertos,
        count() - sum(correta) as total_erros
      FROM resolucaos
      WHERE user_id = ? 
        AND created_at >= now() - INTERVAL ? DAY",
      current_user.id, days
    ]

    if disciplina_id.present?
      sql_parts[0] += " AND disciplina_id = ?"
      sql_parts << disciplina_id
    end

    sql_parts[0] += " GROUP BY assunto_nome ORDER BY total_resolucoes DESC"

    query = ActiveRecord::Base.sanitize_sql_array(sql_parts)

    stats = ClickhouseSyncService.client.query(query).to_hashes
    render json: stats
  end

  private

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
