class Texto < ApplicationRecord
  belongs_to :prova
  belongs_to :concurso
  has_many :questaos


end
