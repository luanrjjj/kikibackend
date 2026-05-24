class CreateReports < ActiveRecord::Migration[7.1]
  def change
    create_table :reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :questao, null: false, foreign_key: true
      t.string :error_type, null: false
      t.text :description, null: false
      t.string :status, default: 'pending'

      t.timestamps
    end
  end
end
