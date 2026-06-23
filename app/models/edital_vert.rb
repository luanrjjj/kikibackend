class EditalVert < ApplicationRecord
  self.table_name = "edital_vert"

  belongs_to :concurso, optional: true
  belongs_to :prova, optional: true

  # Ensure serialize/parsing for json is handled correctly by Rails if needed,
  # but with pg json column Rails handles serialization automatically as a Hash/Array.
end
