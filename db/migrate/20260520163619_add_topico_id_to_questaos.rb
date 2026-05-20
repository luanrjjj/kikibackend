class AddTopicoIdToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_reference :questaos, :topico, null: true, foreign_key: true
  end
end
