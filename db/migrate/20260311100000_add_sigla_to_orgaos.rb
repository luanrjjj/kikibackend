class AddSiglaToOrgaos < ActiveRecord::Migration[8.0]
  def change
    add_column :orgaos, :sigla, :string
  end
end
