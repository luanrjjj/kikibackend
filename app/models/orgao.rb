class Orgao < ApplicationRecord
  has_many :concursos

  validates :esfera, inclusion: { in: %w(municipal estadual federal),
    message: "%{value} is not a valid sphere (must be municipal, estadual or federal)" }, allow_nil: true
end
