class AddIsBlockedToProvas < ActiveRecord::Migration[8.0]
  def change
    add_column :provas, :is_blocked, :boolean, default: false, null: false
    add_index :provas, :is_blocked
  end
end
