class AddEstagioToConcursos < ActiveRecord::Migration[8.0]
  def change
    add_column :concursos, :estagio, :string
  end
end
