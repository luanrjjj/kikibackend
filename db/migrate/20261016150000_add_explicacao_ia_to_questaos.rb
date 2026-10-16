# Explicação da questão gerada por IA (kikiapps#22).
#
# - questaos.deepseek_explicacao: a explicação gerada pelo DeepSeek, salva uma
#   vez e reaproveitada para todos os usuários. Outros provedores ganham a
#   própria coluna (<provedor>_explicacao) quando entrarem.
# - explicacao_ia_avaliacoes: o usuário diz se a explicação ajudou ou não
#   (uma avaliação por usuário, questão e provedor).
class AddExplicacaoIaToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :deepseek_explicacao, :jsonb

    create_table :explicacao_ia_avaliacoes do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :questao, null: false, foreign_key: true
      t.string :provedor, null: false, default: 'deepseek'
      t.boolean :util, null: false

      t.timestamps
    end

    add_index :explicacao_ia_avaliacoes, %i[user_id questao_id provedor], unique: true,
              name: 'index_explicacao_ia_avaliacoes_unica'
  end
end
