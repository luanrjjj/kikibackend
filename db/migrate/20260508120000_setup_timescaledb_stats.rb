class SetupTimescaledbStats < ActiveRecord::Migration[8.0]
  def up
    # Create view for user stats (daily resolution performance) using standard Postgres
    execute <<~SQL
      CREATE OR REPLACE VIEW user_resolution_stats AS
      SELECT
        date_trunc('day', created_at) AS bucket,
        user_id,
        count(*) AS total_resolucoes,
        count(*) FILTER (WHERE correta = true) AS total_acertos,
        count(*) FILTER (WHERE correta = false) AS total_erros
      FROM resolucaos
      GROUP BY 1, 2;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS user_resolution_stats;"
    execute "ALTER TABLE resolucaos DROP CONSTRAINT IF EXISTS resolucaos_pkey CASCADE;"
    execute "ALTER TABLE resolucaos ADD PRIMARY KEY (id);"
  end
end
