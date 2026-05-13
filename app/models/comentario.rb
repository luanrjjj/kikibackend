class Comentario < ApplicationRecord
  belongs_to :prova, optional: true
  belongs_to :user
  belongs_to :concurso, optional: true
  belongs_to :questao

  has_many :voto_comentarios, dependent: :destroy

  validates :user_id, :questao_id, presence: true
end
