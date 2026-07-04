class Anotacao < ApplicationRecord
  belongs_to :user
  belongs_to :questao

  validates :user_id, uniqueness: { scope: :questao_id, message: "só pode ter uma anotação por questão" }
  validates :texto, presence: true
end
