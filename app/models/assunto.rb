class Assunto < ApplicationRecord
  belongs_to :disciplina
  has_many :topicos
  has_many :questaos
  validates :nome, presence: true
end
