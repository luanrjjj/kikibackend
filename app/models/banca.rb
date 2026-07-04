class Banca < ApplicationRecord
  has_many :concursos
  has_many :provas

  def self.order_by_priority
    order(Arel.sql("
      CASE 
        WHEN UPPER(sigla) IN ('CEBRASPE (CESPE)', 'CESPE / CEBRASPE', 'CESPE', 'CEBRASPE') THEN 1
        WHEN UPPER(sigla) = 'FGV' THEN 2
        WHEN UPPER(sigla) = 'CESGRANRIO' THEN 3
        WHEN UPPER(sigla) = 'FCC' THEN 4
        ELSE 5
      END
    "))
  end
end
