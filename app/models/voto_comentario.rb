class VotoComentario < ApplicationRecord
  belongs_to :user
  belongs_to :comentario

  validates :user_id, :comentario_id, presence: true
  validates :user_id, uniqueness: { scope: :comentario_id, message: "Você já votou neste comentário" }
  validates :valor, inclusion: { in: [ 1, -1 ], message: "Valor de voto inválido" }
end
