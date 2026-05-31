class AddProvaUrlRefToProvas < ActiveRecord::Migration[8.0]
  def change
    add_column :provas, :prova_url_ref, :string
  end
end
