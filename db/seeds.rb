# encoding: UTF-8
ActiveRecord::Base.transaction do
  # Planos Seeds
  Plano.find_or_create_by!(nome_do_plano: 'Free') do |p|
    p.valor_mensal = 0.00
    p.valor_promocional_mensal = 0.00
    p.valor_anual = 0.00
    p.valor_promocional_anual = 0.00
    p.data_inicio_promocao = Time.current
    p.data_fim_promocao = 1.year.from_now
  end

  Plano.find_or_create_by!(nome_do_plano: 'Medium') do |p|
    p.valor_mensal = 29.90
    p.valor_promocional_mensal = 19.90
    p.valor_anual = 299.00
    p.valor_promocional_anual = 199.00
    p.data_inicio_promocao = Time.current
    p.data_fim_promocao = 1.month.from_now
  end

  Plano.find_or_create_by!(nome_do_plano: 'Pro') do |p|
    p.valor_mensal = 59.90
    p.valor_promocional_mensal = 44.90
    p.valor_anual = 599.00
    p.valor_promocional_anual = 449.00
    p.data_inicio_promocao = Time.current
    p.data_fim_promocao = 6.months.from_now
  end
end

SeedMigration::Migrator.bootstrap(20260227124408)
puts 'Planos seeded successfully!'
