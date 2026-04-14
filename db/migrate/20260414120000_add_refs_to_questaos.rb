class AddRefsToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :disciplina_ref, :string
    add_column :questaos, :assunto_ref, :string, array: true, default: []
  end
end
