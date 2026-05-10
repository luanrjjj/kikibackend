class AddCounterCachesToBancas < ActiveRecord::Migration[8.0]
  def change
    add_column :bancas, :questaos_count, :integer, default: 0
    add_column :bancas, :com_gabarito_count, :integer, default: 0
    add_index :bancas, :questaos_count
  end
end
