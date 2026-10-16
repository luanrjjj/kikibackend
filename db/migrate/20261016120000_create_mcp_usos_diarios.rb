# Quantas questões cada usuário recebeu pelo acesso por IA (MCP e
# /api/anki/questoes com token pessoal) em cada dia. Base da cota diária
# (McpCotaDiaria::LIMITE_DIARIO).
class CreateMcpUsosDiarios < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_usos_diarios do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.date :dia, null: false
      t.integer :questoes, null: false, default: 0

      t.timestamps
    end

    add_index :mcp_usos_diarios, %i[user_id dia], unique: true
  end
end
