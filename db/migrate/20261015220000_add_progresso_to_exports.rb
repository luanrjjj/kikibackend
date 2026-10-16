# Progresso (0-100) da exportação do Anki em fila, para a barra de progresso do frontend.
class AddProgressoToExports < ActiveRecord::Migration[8.0]
  def change
    # Exportações antigas já estão concluídas
    add_column :exports, :progresso, :integer, null: false, default: 0
    reversible do |dir|
      dir.up { execute "UPDATE exports SET progresso = 100 WHERE status = 'concluido'" }
    end
  end
end
