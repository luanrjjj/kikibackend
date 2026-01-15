class Disciplina < ApplicationRecord
  has_many :assuntos
  has_many :topicos
  has_many :questaos
  validates :nome, presence: true
end
