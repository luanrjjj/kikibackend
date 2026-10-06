class AddIsBlockedToConcursos < ActiveRecord::Migration[8.0]
  def change
    add_column :concursos, :is_blocked, :boolean, default: false, null: false
    add_index :concursos, :is_blocked
  end
end
