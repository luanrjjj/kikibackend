# Texto candidato (criado na tabela textos pelo script
# ankigenerator/assign_text_to_verify.py) para questões com problema de texto.
# O admin confere na aba Questões antes de vincular como texto_id.
class AddTextToVerifyToQuestaos < ActiveRecord::Migration[8.0]
  def change
    add_column :questaos, :text_to_verify, :bigint
    add_index :questaos, :text_to_verify
  end
end
