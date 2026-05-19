class Filtro < ApplicationRecord
  belongs_to :user, optional: true
  has_many :cadernos, dependent: :nullify
end
