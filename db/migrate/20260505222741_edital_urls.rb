class EditalUrls < ActiveRecord::Migration[8.0]
  def change
      add_column :provas, :edital_url, :string
      add_column :provas, :prova_url, :string
      add_column :concursos, :pdf_folder_url, :string
  end
end
