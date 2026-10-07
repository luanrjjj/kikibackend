class AddDefaultMaxCadernoQuestoesToConfigGlobalApolo < ActiveRecord::Migration[8.0]
  def up
    if table_exists?(:config_global_apolo)
      execute <<-SQL
        INSERT INTO config_global_apolo (nome_da_variavel, valor_da_variavel, created_at, updated_at)
        SELECT 'max_caderno_questoes', '10000', NOW(), NOW()
        WHERE NOT EXISTS (
          SELECT 1 FROM config_global_apolo WHERE nome_da_variavel = 'max_caderno_questoes'
        );
      SQL
    end
  end

  def down
    if table_exists?(:config_global_apolo)
      execute "DELETE FROM config_global_apolo WHERE nome_da_variavel = 'max_caderno_questoes';"
    end
  end
end
