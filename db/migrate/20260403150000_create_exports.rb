class CreateExports < ActiveRecord::Migration[8.0]
  def change
    create_table :exports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :prova, null: true, foreign_key: true
      t.references :concurso, null: true, foreign_key: true
      t.integer :questoes_count, null: false, default: 0

      t.timestamps
    end
  end
end
