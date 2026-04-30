class Concurso < ApplicationRecord
  belongs_to :banca
  belongs_to :orgao
  has_many :provas, dependent: :destroy
  has_many :questaos, dependent: :destroy
  has_many :textos, dependent: :destroy
  has_many :comentarios, dependent: :destroy
end
