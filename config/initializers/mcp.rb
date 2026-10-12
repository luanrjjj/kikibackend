# Configuração global da gem `mcp` (servidor em /api/mcp, ver docs/MCP.md).
MCP.configure do |config|
  # Erros dentro das ferramentas chegam ao cliente só como "Internal error";
  # o detalhe vai para o log.
  config.exception_reporter = lambda do |exception, _contexto|
    Rails.logger.error(
      "[MCP] #{exception.class}: #{exception.message}\n#{exception.backtrace&.first(15)&.join("\n")}"
    )
  end
end
