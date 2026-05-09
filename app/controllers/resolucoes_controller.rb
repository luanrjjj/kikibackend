class ResolucoesController < ApplicationController
  def create
    @questao = Questao.find(params[:resolucao][:questao_id])
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
    
    stats = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT bucket as date, total_resolucoes, total_acertos, total_erros 
         FROM user_resolution_stats 
         WHERE user_id = ? AND bucket >= (NOW() - INTERVAL '? days')
         ORDER BY bucket DESC", 
        current_user.id, days
      ])
    )
    render json: stats
  end

  def discipline_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30

    stats = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT d.nome as disciplina_nome, 
                d.id as disciplina_id,
                SUM(total_resolucoes) as total_resolucoes, 
                SUM(total_acertos) as total_acertos, 
                SUM(total_erros) as total_erros
         FROM user_discipline_stats uds
         JOIN disciplinas d ON uds.disciplina_id = d.id
         WHERE user_id = ? AND bucket >= (NOW() - INTERVAL '? days')
         GROUP BY d.nome, d.id
         ORDER BY total_resolucoes DESC",
        current_user.id, days
      ])
    )
    render json: stats
  end

  def subject_stats
    days = params[:days].to_i > 0 ? params[:days].to_i : 30
    disciplina_id = params[:disciplina_id]

    query = <<~SQL
      SELECT a.nome as assunto_nome, 
             SUM(total_resolucoes) as total_resolucoes, 
             SUM(total_acertos) as total_acertos, 
             SUM(total_erros) as total_erros
      FROM user_subject_stats uss
      JOIN assuntos a ON uss.assunto_id = a.id
      WHERE user_id = ? AND bucket >= (NOW() - INTERVAL '? days')
    SQL

    args = [current_user.id, days]

    if disciplina_id.present?
      query += " AND uss.disciplina_id = ?"
      args << disciplina_id
    end

    query += " GROUP BY a.nome ORDER BY total_resolucoes DESC"

    stats = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([query, *args])
    )
    render json: stats
  end

  private

  def resolucao_params
    params.require(:resolucao).permit(:questao_id, :caderno_id, :resposta)
  end
end
