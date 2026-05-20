class Topico < ApplicationRecord
  belongs_to :disciplina
  belongs_to :assunto
  has_many :questaos
  validates :nome, presence: true
end