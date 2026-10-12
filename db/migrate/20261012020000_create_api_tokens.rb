class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :nome, null: false
      # Só guardamos o SHA-256 do token. O token em si aparece uma única vez,
      # na resposta de criação.
      t.string :token_digest, null: false
      # Primeiros caracteres do token, para o usuário reconhecer qual é qual na tela.
      t.string :token_prefixo, null: false
      t.datetime :last_used_at
      t.datetime :revogado_em

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, [:user_id, :revogado_em]
  end
end
