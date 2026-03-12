class CreatePagamentos < ActiveRecord::Migration[8.0]
  def change
    create_table :pagamentos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :gateway
      t.string :consumer_id

      t.timestamps
    end
  end
end
