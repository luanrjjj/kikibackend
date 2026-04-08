class Banca < ApplicationRecord
  has_many :concursos
  has_many :provas
end
