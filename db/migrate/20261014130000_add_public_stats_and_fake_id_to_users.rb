# Perfil estatístico público (kikiapps#1).
# - public_stats: o usuário permite que suas estatísticas sejam vistas por link.
# - fake_id: identificador público de 7 dígitos usado na URL
#   (/perfil/<fake_id>), para não expor o id real do usuário.
class AddPublicStatsAndFakeIdToUsers < ActiveRecord::Migration[8.0]
  class MigrationUser < ActiveRecord::Base
    self.table_name = 'users'
  end

  def up
    add_column :users, :public_stats, :boolean, null: false, default: false
    add_column :users, :fake_id, :string, limit: 7

    usados = Set.new
    MigrationUser.where(fake_id: nil).find_each do |user|
      fake_id = nil
      loop do
        fake_id = SecureRandom.random_number(1_000_000..9_999_999).to_s
        break unless usados.include?(fake_id)
      end
      usados << fake_id
      user.update_columns(fake_id: fake_id)
    end

    change_column_null :users, :fake_id, false
    add_index :users, :fake_id, unique: true
  end

  def down
    remove_index :users, :fake_id
    remove_column :users, :fake_id
    remove_column :users, :public_stats
  end
end
