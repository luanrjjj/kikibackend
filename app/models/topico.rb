class Topico < ApplicationRecord
  belongs_to :disciplina
  belongs_to :assunto
  validates :nome, presence: true
end