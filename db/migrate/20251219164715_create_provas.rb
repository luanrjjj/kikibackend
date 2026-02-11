class CreateProvas < ActiveRecord::Migration[8.0]
  def change
    create_table :provas do |t|
      t.string :nome, null: false
      t.references :orgao, index: true, null: false, foreign_key: true
      t.references :banca, index: true, null: false, foreign_key: true
      t.references :concurso, index: true, null: false, foreign_key: true
      t.references :area_de_formacao, index: true, foreign_key: true
      t.references :area_de_atuacao, index: true, foreign_key: true
      t.integer :ano
      t.string :escolaridade
      t.string :pdfs_folder_url
      t.timestamps
    end
  end
end
    '                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   '