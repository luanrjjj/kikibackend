require "test_helper"

class McpFerramentasPaginacaoTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def pag(**args)
    Mcp::Ferramentas.paginacao(**args)
  end

  test "primeira página de várias" do
    p = pag(total: 250, inicio: 0, quantidade: 100, entregues: 100)
    assert_equal 1, p[:pagina]
    assert_equal 3, p[:total_paginas]
    assert p[:tem_mais]
    assert_equal 100, p[:proximo_inicio]
    assert_equal 2, p[:proxima_pagina]
  end

  test "última página não tem próxima" do
    p = pag(total: 250, inicio: 200, quantidade: 100, entregues: 50)
    assert_equal 3, p[:pagina]
    refute p[:tem_mais]
    assert_nil p[:proximo_inicio]
    assert_nil p[:proxima_pagina]
  end

  test "entrega parcial pela cota continua por inicio, sem proxima_pagina" do
    p = pag(total: 250, inicio: 100, quantidade: 100, entregues: 30)
    assert p[:tem_mais]
    assert_equal 130, p[:proximo_inicio]
    assert_nil p[:proxima_pagina]
  end

  test "fora do fim" do
    p = pag(total: 10, inicio: 40, quantidade: 20, entregues: 0)
    refute p[:tem_mais]
    assert_equal 3, p[:pagina]
  end
end
