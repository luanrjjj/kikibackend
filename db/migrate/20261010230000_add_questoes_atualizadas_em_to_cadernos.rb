class AddQuestoesAtualizadasEmToCadernos < ActiveRecord::Migration[8.0]
  def up
    add_column :cadernos, :questoes_atualizadas_em, :datetime
    add_column :cadernos, :questoes_verificadas_em, :datetime

    # Best available value for existing notebooks: the last time the record changed.
    execute <<~SQL
      UPDATE cadernos SET questoes_atualizadas_em = COALESCE(updated_at, created_at)
    SQL
  end

  def down
    remove_column :cadernos, :questoes_verificadas_em
    remove_column :cadernos, :questoes_atualizadas_em
  end
end
