class ConfigGlobalApolo < ApplicationRecord
  self.table_name = "config_global_apolo"

  validates :nome_da_variavel, presence: true, uniqueness: true

  def self.get(nome, padrao = nil)
    find_by(nome_da_variavel: nome)&.valor_da_variavel || padrao
  end

  def self.set(nome, valor)
    config = find_or_initialize_by(nome_da_variavel: nome)
    config.valor_da_variavel = valor
    config.save!
  end
end
