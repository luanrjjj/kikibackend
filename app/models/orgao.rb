class Orgao < ApplicationRecord
  has_many :concursos

  before_validation :normalize_esfera

  validates :esfera, inclusion: { in: %w(municipal estadual federal),
    message: "%{value} is not a valid sphere (must be municipal, estadual or federal)" }, allow_nil: true

  private

  def normalize_esfera
    self.esfera = esfera.to_s.downcase if esfera.present?
  end
end
