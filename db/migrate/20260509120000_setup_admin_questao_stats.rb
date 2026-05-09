class SetupAdminQuestaoStats < ActiveRecord::Migration[8.0]
  def up
    # Create view for admin KPI and charts using standard Postgres
    execute <<~SQL
      CREATE OR REPLACE VIEW admin_questao_stats AS
      SELECT
        date_trunc('hour', created_at) AS bucket,
        ano,
        count(*) AS total_questaos,
        count(validado_admin) AS total_validadas,
        count(CASE WHEN correta IS NOT NULL AND correta != '' THEN 1 END) AS total_com_resposta,
        count(disciplina_id) AS total_com_disciplina,
        count(assunto_id) AS total_com_assunto
      FROM questaos
      GROUP BY 1, 2;
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS admin_questao_stats;"
    execute "ALTER TABLE questaos DROP CONSTRAINT IF EXISTS questaos_pkey CASCADE;"
    execute "ALTER TABLE questaos ADD PRIMARY KEY (id);"
  end
end
