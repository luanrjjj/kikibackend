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
      t.date :data_prova_aplicacao
      t.timestamps
    end
    execute "ALTER SEQUENCE provas_id_seq RESTART WITH 14007;"
  end
end
    '                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   '