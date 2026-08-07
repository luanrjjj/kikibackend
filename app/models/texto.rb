class Texto < ApplicationRecord
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  has_many :questaos


end
