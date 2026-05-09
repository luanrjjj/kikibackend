class AddSubjectStatsToTimescaledb < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Create continuous aggregate for subject stats
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS user_subject_stats
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket('1 day', r.created_at) AS bucket,
        r.user_id,
        q.disciplina_id,
        q.assunto_id,
        count(*) AS total_resolucoes,
        count(*) FILTER (WHERE r.correta = true) AS total_acertos,
        count(*) FILTER (WHERE r.correta = false) AS total_erros
      FROM resolucaos r
      JOIN questaos q ON r.questao_id = q.id
      GROUP BY bucket, r.user_id, q.disciplina_id, q.assunto_id;
    SQL

    # Set refresh policy
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM timescaledb_information.jobs WHERE proc_name = 'policy_refresh_continuous_aggregate' AND hypertable_name = 'user_subject_stats') THEN
          PERFORM add_continuous_aggregate_policy('user_subject_stats',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 hour',
            schedule_interval => INTERVAL '1 hour');
        END IF;
      END $$;
    SQL
  end

  def down
    execute "SELECT remove_continuous_aggregate_policy('user_subject_stats', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS user_subject_stats;"
  end
end
