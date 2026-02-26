class Texto < ApplicationRecord
  belongs_to :prova
  belongs_to :concurso
  has_many :questaos

  def as_json(options = {})
    super(options.merge(except: [:created_at, :updated_at]))
  end
end
