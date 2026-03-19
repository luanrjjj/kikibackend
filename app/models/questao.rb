class Questao < ApplicationRecord
  has_many :prova_questaos, dependent: :destroy
  has_many :provas, through: :prova_questaos

  belongs_to :concurso, optional: true
  belongs_to :assunto, optional: true
  belongs_to :disciplina, optional: true

  belongs_to :texto, optional: true

  validates :enunciado, presence: true
  validates :ano, presence: true
  validates :discursiva, inclusion: { in: [true, false] }


end