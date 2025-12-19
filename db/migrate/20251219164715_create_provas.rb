class CreateProvas < ActiveRecord::Migration[8.0]
  def change
    create_table :provas do |t|
      t.timestamps
    end
  end
end
