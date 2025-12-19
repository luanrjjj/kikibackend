class CreateConcursos < ActiveRecord::Migration[8.0]
  def change
    create_table :concursos do |t|
      t.timestamps
    end
  end
end
