class CreateOrgaos < ActiveRecord::Migration[8.0]
  def change
    create_table :orgaos do |t|
      t.string :nome, null: false
      t.string :sede
      t.string :logo_url
      t.timestamps
    end
  end
end
