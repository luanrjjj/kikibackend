class SetupAdminQuestaoStats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Convert questaos to hypertable using created_at
    execute "ALTER TABLE questaos DROP CONSTRAINT IF EXISTS questaos_pkey CASCADE;"
    execute "ALTER TABLE questaos ADD PRIMARY KEY (id, created_at);"
    
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM timescaledb_information.hypertables WHERE hypertable_name = 'questaos') THEN
          PERFORM create_hypertable('questaos', 'created_at', migrate_data => true);
        END IF;
      END $$;
    SQL

    # Create continuous aggregate for admin KPI and charts
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS admin_questao_stats
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket('1 hour', created_at) AS bucket,
        ano,
        count(*) AS total_questaos,
        count(validado_admin) AS total_validadas,
        count(CASE WHEN correta IS NOT NULL AND correta != '' THEN 1 END) AS total_com_resposta,
        count(disciplina_id) AS total_com_disciplina,
        count(assunto_id) AS total_com_assunto
      FROM questaos
      GROUP BY bucket, ano;
    SQL

    # Set refresh policy to run every hour
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM timescaledb_information.jobs WHERE proc_name = 'policy_refresh_continuous_aggregate' AND hypertable_name = 'admin_questao_stats') THEN
          PERFORM add_continuous_aggregate_policy('admin_questao_stats',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 hour',
            schedule_interval => INTERVAL '1 hour');
        END IF;
      END $$;
    SQL
  end

  def down
    execute "SELECT remove_continuous_aggregate_policy('admin_questao_stats', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS admin_questao_stats;"
    execute "ALTER TABLE questaos DROP CONSTRAINT IF EXISTS questaos_pkey CASCADE;"
    execute "ALTER TABLE questaos ADD PRIMARY KEY (id);"
  end
end
