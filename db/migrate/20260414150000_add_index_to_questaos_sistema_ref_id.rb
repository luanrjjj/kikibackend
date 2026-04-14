class AddIndexToQuestaosSistemaRefId < ActiveRecord::Migration[8.0]
  def change
    add_index :questaos, :sistema_ref_id
  end
end
