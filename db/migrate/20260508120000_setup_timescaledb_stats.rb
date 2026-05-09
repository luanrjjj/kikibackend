class SetupTimescaledbStats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Enable TimescaleDB extension
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"

    # Convert resolucaos to hypertable
    # TimescaleDB requires the partitioning column to be part of the primary key
    execute "ALTER TABLE resolucaos DROP CONSTRAINT IF EXISTS resolucaos_pkey CASCADE;"
    execute "ALTER TABLE resolucaos ADD PRIMARY KEY (id, created_at);"
    
    # create_hypertable with migrate_data => true for non-empty tables
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM timescaledb_information.hypertables WHERE hypertable_name = 'resolucaos') THEN
          PERFORM create_hypertable('resolucaos', 'created_at', migrate_data => true);
        END IF;
      END $$;
    SQL

    # Create continuous aggregate for user stats (daily resolution performance)
    execute <<~SQL
      CREATE MATERIALIZED VIEW IF NOT EXISTS user_resolution_stats
      WITH (timescaledb.continuous) AS
      SELECT
        time_bucket('1 day', created_at) AS bucket,
        user_id,
        count(*) AS total_resolucoes,
        count(*) FILTER (WHERE correta = true) AS total_acertos,
        count(*) FILTER (WHERE correta = false) AS total_erros
      FROM resolucaos
      GROUP BY bucket, user_id;
    SQL

    # Set refresh policy for the continuous aggregate
    execute <<~SQL
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM timescaledb_information.jobs WHERE proc_name = 'policy_refresh_continuous_aggregate' AND hypertable_name = 'user_resolution_stats') THEN
          PERFORM add_continuous_aggregate_policy('user_resolution_stats',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 hour',
            schedule_interval => INTERVAL '1 hour');
        END IF;
      END $$;
    SQL
  end

  def down
    execute "SELECT remove_continuous_aggregate_policy('user_resolution_stats', if_exists => true);"
    execute "DROP MATERIALIZED VIEW IF EXISTS user_resolution_stats;"
    execute "ALTER TABLE resolucaos DROP CONSTRAINT IF EXISTS resolucaos_pkey CASCADE;"
    execute "ALTER TABLE resolucaos ADD PRIMARY KEY (id);"
  end
end
