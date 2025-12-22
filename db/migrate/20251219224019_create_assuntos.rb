class CreateAssuntos < ActiveRecord::Migration[8.0]
  def change
    create_table :assuntos do |t|
      t.timestamps
    end
  end
end
