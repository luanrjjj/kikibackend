require "test_helper"

class PlanoTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def assinante(plan)
    User.create!(email: "#{plan.downcase}_#{SecureRandom.hex(4)}@example.com", password: "password",
                 plan: plan, subscription_status: "ACTIVE", current_period_end: 1.month.from_now)
  end

  test "interpreta booleanos em qualquer caixa, números e chaves sem valor" do
    vars = Plano.interpretar(["create_notebook_basic:True", "guide_access:FALSE", "limit_resolutions_free:100", "mcp_access", "x:abc"])

    assert_equal({ "create_notebook_basic" => true, "guide_access" => false, "limit_resolutions_free" => 100, "mcp_access" => true, "x" => "abc" }, vars)
  end

  test "nível da assinatura" do
    assert_equal :basic, Plano.nivel_da_assinatura("BASIC")
    assert_equal :basic, Plano.nivel_da_assinatura("Básico")
    assert_equal :advanced, Plano.nivel_da_assinatura("PRO")
    assert_equal :advanced, Plano.nivel_da_assinatura("MONTHLY")
  end

  test "sem plano no banco, vale o padrão do nível" do
    Plano.delete_all
    free = User.create!(email: "free_#{SecureRandom.hex(4)}@example.com", password: "password")

    assert_equal :free, free.plano_nivel
    assert_equal 100, free.limite_resolucoes
    assert free.pode?("create_notebook_basic")
    assert_not free.pode?("guide_access")
    assert_not free.pode?("mcp_access")

    basico = assinante("BASIC")
    assert basico.pode?("guide_access")
    assert basico.pode?("edital_verticalized_advanced")
    assert_not basico.pode?("mcp_access")
    assert_nil basico.limite_resolucoes

    pro = assinante("PRO")
    assert pro.pode?("mcp_access")
    assert pro.pode?("excel_stats_export_advanced")
  end

  test "o plano do banco vale sobre o padrão, e Pro é o mesmo nível que Advanced" do
    Plano.delete_all
    Plano.create!(nome_do_plano: "Pro", variaveis: ["guide_access:true", "mcp_access:false"])

    pro = assinante("PRO")
    assert pro.pode?("guide_access")
    assert_not pro.pode?("mcp_access")
    assert_not pro.pode?("excel_stats_export_advanced")
  end

  test "assinatura expirada volta ao plano gratuito" do
    user = assinante("PRO")
    user.update!(current_period_end: 1.day.ago)

    assert_equal :free, user.plano_nivel
    assert_not user.pode?("mcp_access")
  end

  test "admin pode tudo e não tem limites" do
    admin = User.create!(email: "admin_#{SecureRandom.hex(4)}@example.com", password: "password", admin: true)

    Plano::RECURSOS_BOOLEANOS.each { |r| assert admin.pode?(r), r }
    assert_nil admin.limite_resolucoes
    assert_nil admin.limite_exportacoes_semana
  end
end
