module Mcp
  # Servidor MCP (Model Context Protocol) do Apolo, transporte "Streamable HTTP"
  # sem estado: cada POST /api/mcp traz uma mensagem JSON-RPC 2.0 e recebe a
  # resposta em JSON na mesma requisição.
  #
  # Implementado à mão, sem a gem `mcp`, para não mexer no Gemfile.lock. O
  # protocolo usado aqui é pequeno: initialize, ping, tools/list e tools/call.
  #
  # Especificação: https://modelcontextprotocol.io/specification/2025-06-18
  class Servidor
    VERSOES_SUPORTADAS = %w[2025-06-18 2025-03-26 2024-11-05].freeze
    NOME = 'apolo'.freeze
    VERSAO = '1.0.0'.freeze

    PARSE_ERROR = -32_700
    INVALID_REQUEST = -32_600
    METHOD_NOT_FOUND = -32_601
    INVALID_PARAMS = -32_602
    INTERNAL_ERROR = -32_603

    INSTRUCOES = <<~TXT.freeze
      Servidor do Apolo, plataforma de questões de concurso. Todas as ferramentas
      leem dados do próprio usuário dono do token; nenhuma altera nada.

      Para entender o desempenho: comece por estatisticas_gerais e pontos_fracos.
      Para um caderno específico: listar_cadernos e depois estatisticas_caderno.
      Para revisar erros ou montar flashcards: questoes_erradas devolve os ids e
      questoes_para_anki devolve enunciado, alternativas, gabarito e classificação
      de até 50 questões por chamada.

      Taxas de acerto estão em porcentagem (0 a 100). Datas no formato AAAA-MM-DD.
    TXT

    def initialize(user:)
      @user = user
      @ferramentas = Ferramentas.new(user)
    end

    # @param mensagem [Hash, Array] JSON-RPC já decodificado
    # @return [Hash, Array, nil] resposta; nil quando só havia notificações
    def processar(mensagem)
      if mensagem.is_a?(Array)
        return erro(nil, INVALID_REQUEST, 'Lote vazio.') if mensagem.empty?

        respostas = mensagem.map { |m| processar_uma(m) }.compact
        respostas.empty? ? nil : respostas
      else
        processar_uma(mensagem)
      end
    end

    def self.erro_de_parse
      { jsonrpc: '2.0', id: nil, error: { code: PARSE_ERROR, message: 'JSON inválido.' } }
    end

    private

    def processar_uma(mensagem)
      unless mensagem.is_a?(Hash) && mensagem['jsonrpc'] == '2.0' && mensagem['method'].is_a?(String)
        # Resposta de um cliente para um pedido nosso: não fazemos pedidos, ignora.
        return nil if mensagem.is_a?(Hash) && (mensagem.key?('result') || mensagem.key?('error'))

        return erro(mensagem.is_a?(Hash) ? mensagem['id'] : nil, INVALID_REQUEST, 'Requisição JSON-RPC inválida.')
      end

      id = mensagem['id']
      notificacao = !mensagem.key?('id')
      params = mensagem['params'] || {}

      resultado = despachar(mensagem['method'], params)
      return nil if notificacao

      { jsonrpc: '2.0', id: id, result: resultado }
    rescue ErroJsonRpc => e
      notificacao ? nil : erro(id, e.codigo, e.message)
    rescue StandardError => e
      Rails.logger.error("[MCP] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
      notificacao ? nil : erro(id, INTERNAL_ERROR, 'Erro interno do servidor.')
    end

    def despachar(metodo, params)
      case metodo
      when 'initialize' then inicializar(params)
      when 'ping' then {}
      when 'tools/list' then { tools: @ferramentas.definicoes }
      when 'tools/call' then chamar_ferramenta(params)
      when %r{\Anotifications/} then nil
      else
        raise ErroJsonRpc.new(METHOD_NOT_FOUND, "Método não suportado: #{metodo}")
      end
    end

    def inicializar(params)
      pedida = params.is_a?(Hash) ? params['protocolVersion'] : nil
      versao = VERSOES_SUPORTADAS.include?(pedida) ? pedida : VERSOES_SUPORTADAS.first

      {
        protocolVersion: versao,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: NOME, title: 'Apolo Concursos', version: VERSAO },
        instructions: INSTRUCOES
      }
    end

    def chamar_ferramenta(params)
      raise ErroJsonRpc.new(INVALID_PARAMS, 'params deve ser um objeto.') unless params.is_a?(Hash)

      nome = params['name']
      raise ErroJsonRpc.new(INVALID_PARAMS, "Ferramenta desconhecida: #{nome.inspect}") unless @ferramentas.existe?(nome)

      argumentos = params['arguments'] || {}
      raise ErroJsonRpc.new(INVALID_PARAMS, 'arguments deve ser um objeto.') unless argumentos.is_a?(Hash)

      dados = @ferramentas.chamar(nome, argumentos)
      {
        content: [{ type: 'text', text: JSON.generate(dados) }],
        structuredContent: dados,
        isError: false
      }
    rescue Ferramentas::ErroDeFerramenta => e
      # Erro de uso (argumento inválido, plano sem permissão etc.): volta como
      # resultado com isError, para o modelo ler a mensagem e corrigir.
      { content: [{ type: 'text', text: e.message }], isError: true }
    end

    def erro(id, codigo, mensagem)
      { jsonrpc: '2.0', id: id, error: { code: codigo, message: mensagem } }
    end

    class ErroJsonRpc < StandardError
      attr_reader :codigo

      def initialize(codigo, mensagem)
        @codigo = codigo
        super(mensagem)
      end
    end
  end
end
