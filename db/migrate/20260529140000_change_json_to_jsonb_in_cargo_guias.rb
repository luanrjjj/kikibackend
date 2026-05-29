class ChangeJsonToJsonbInCargoGuias < ActiveRecord::Migration[8.0]
  def change
    change_column :cargo_guias, :filtro_ids, :jsonb, using: 'filtro_ids::jsonb', default: []
  end
end
