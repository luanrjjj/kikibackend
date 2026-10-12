# Cada usuário pode ter só um token pessoal ativo.
class UmTokenAtivoPorUsuario < ActiveRecord::Migration[8.0]
  def up
    # Se algum usuário já tiver mais de um ativo, mantém só o mais recente.
    execute <<~SQL
      UPDATE api_tokens SET revogado_em = NOW(), updated_at = NOW()
      WHERE revogado_em IS NULL
        AND id NOT IN (
          SELECT DISTINCT ON (user_id) id FROM api_tokens
          WHERE revogado_em IS NULL
          ORDER BY user_id, created_at DESC, id DESC
        )
    SQL

    add_index :api_tokens, :user_id, unique: true, where: 'revogado_em IS NULL',
                                     name: 'index_api_tokens_on_user_id_ativo'
  end

  def down
    remove_index :api_tokens, name: 'index_api_tokens_on_user_id_ativo'
  end
end
