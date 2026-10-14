# Exportação do Anki em fila (AnkiExportJob): status do processamento,
# arquivo gerado no Spaces e o payload enviado pelo frontend até o job rodar.
class AddFilaToExports < ActiveRecord::Migration[8.0]
  def change
    # Exportações antigas eram síncronas e já foram entregues
    add_column :exports, :status, :string, null: false, default: 'concluido'
    add_column :exports, :titulo, :string
    add_column :exports, :arquivo_key, :string
    add_column :exports, :erro, :text
    add_column :exports, :payload, :jsonb
    add_column :exports, :concluido_em, :datetime
    add_index :exports, :status
  end
end
