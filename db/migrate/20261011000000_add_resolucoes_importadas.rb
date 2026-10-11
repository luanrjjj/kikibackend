# "Atualizar resoluções" do caderno: copia a resolução mais recente que o
# usuário fez de cada questão em outro lugar para dentro do caderno.
#
# - resolucaos.importada_de_id: id da resolução original quando a linha é uma
#   cópia importada. Cópias ficam fora das estatísticas globais do usuário
#   (só contam no caderno), evitando contagem em dobro.
# - cadernos.resolucoes_atualizadas_em: data da última importação.
class AddResolucoesImportadas < ActiveRecord::Migration[8.0]
  def up
    add_column :resolucaos, :importada_de_id, :bigint
    add_column :cadernos, :resolucoes_atualizadas_em, :datetime

    execute <<~SQL
      CREATE OR REPLACE VIEW user_resolution_stats AS
      SELECT
        date_trunc('day', created_at) AS bucket,
        user_id,
        count(*) AS total_resolucoes,
        count(*) FILTER (WHERE correta = true) AS total_acertos,
        count(*) FILTER (WHERE correta = false) AS total_erros
      FROM resolucaos
      WHERE importada_de_id IS NULL
      GROUP BY 1, 2;
    SQL
  end

  def down
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

    remove_column :cadernos, :resolucoes_atualizadas_em
    remove_column :resolucaos, :importada_de_id
  end
end
