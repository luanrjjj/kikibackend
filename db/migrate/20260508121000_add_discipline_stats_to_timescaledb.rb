class AddDisciplineStatsToTimescaledb < ActiveRecord::Migration[8.0]
  def up
    # Create view for discipline stats using standard Postgres
    execute <<~SQL
      CREATE OR REPLACE VIEW user_discipline_stats AS
      SELECT
        date_trunc('day', r.created_at) AS bucket,
        r.user_id,
        q.disciplina_id,
        count(*) AS total_resolucoes,
        count(*) FILTER (WHERE r.correta = true) AS total_acertos,
        count(*) FILTER (WHERE r.correta = false) AS total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      GROUP BY 1, 2, 3;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS user_discipline_stats;"
  end
end
