# Reconfigura as variáveis dos planos Free, Básico e Avançado (Pro) com os
# valores de Plano::PADROES.
#
# Os planos são encontrados pelo nome, sem diferenciar maiúsculas (ver
# Plano::NIVEIS: "Advanced" e "Pro" são o mesmo nível). Variáveis que não são
# recursos conhecidos (ex.: max_caderno_questoes) são mantidas.
class ReconfiguraPlanos < SeedMigration::Migration
  NOMES_PADRAO = { free: 'Free', basic: 'Basic', advanced: 'Advanced' }.freeze
  OBSOLETAS = %w[create_notebook_free].freeze

  def up
    conhecidas = Plano::RECURSOS_BOOLEANOS + Plano::RECURSOS_COM_LIMITE + OBSOLETAS

    Plano::PADROES.each do |nivel, valores|
      planos = Plano.where('LOWER(nome_do_plano) IN (?)', Plano::NIVEIS.fetch(nivel)).to_a
      planos = [Plano.create!(nome_do_plano: NOMES_PADRAO.fetch(nivel), valor_mensal: (0 if nivel == :free))] if planos.empty?

      planos.each do |plano|
        mantidas = plano.variaveis_hash.except(*conhecidas)
        plano.update!(variaveis: Plano.serializar(mantidas.merge(valores)))
      end
    end
  end

  def down
  end
end
