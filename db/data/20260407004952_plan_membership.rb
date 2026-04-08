class PlanMembership < SeedMigration::Migration
  def up
    Plano.find_or_create_by!(nome_do_plano: "Free") do |p|
      p.valor_mensal = 0.00
      p.valor_anual = 0.00
    end

    Plano.find_or_create_by!(nome_do_plano: "Basic") do |p|
      p.valor_mensal = 19.90
      p.valor_anual = 199.00
    end

    Plano.find_or_create_by!(nome_do_plano: "Pro") do |p|
      p.valor_mensal = 39.90
      p.valor_anual = 399.00
    end
  end

  def down

  end
end
