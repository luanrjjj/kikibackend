module Mcp
  # Servidor MCP do Apolo, montado com a gem oficial `mcp`
  # (https://github.com/modelcontextprotocol/ruby-sdk).
  #
  # As ferramentas são criadas uma vez, a partir de Mcp::Ferramentas::DEFINICOES.
  # O servidor é criado por requisição, com o usuário dono do token no
  # server_context, como no padrão "Rails (controller)" da documentação da gem.
  module Servidor
    NOME = 'apolo'.freeze
    VERSAO = '1.0.0'.freeze

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

    # Uma classe MCP::Tool por ferramenta. O bloco recebe os argumentos com
    # chaves em símbolo (a gem já validou contra o inputSchema) e repassa para
    # Mcp::Ferramentas.
    FERRAMENTAS = Ferramentas::DEFINICOES.map do |definicao|
      nome = definicao[:name]

      MCP::Tool.define(
        name: nome,
        title: definicao[:title],
        description: definicao[:description],
        input_schema: definicao[:inputSchema],
        annotations: { title: definicao[:title], read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }
      ) do |server_context:, **argumentos|
        Servidor.executar(nome, server_context[:user], argumentos)
      end
    end.freeze

    module_function

    # @param user [User] dono do token
    # @return [MCP::Server]
    def construir(user)
      MCP::Server.new(
        name: NOME,
        title: 'Apolo Concursos',
        version: VERSAO,
        instructions: INSTRUCOES,
        tools: FERRAMENTAS,
        server_context: { user: user }
      )
    end

    # Executa a ferramenta e converte o resultado em MCP::Tool::Response.
    # Erros de uso (caderno de outro usuário, data inválida, plano sem
    # permissão) voltam com isError para o modelo ler a mensagem e corrigir.
    def executar(nome, user, argumentos)
      dados = Ferramentas.new(user).chamar(nome, argumentos.transform_keys(&:to_s))
      dados = JSON.parse(JSON.generate(dados))

      MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(dados) }], structured_content: dados)
    rescue Ferramentas::ErroDeFerramenta => e
      MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
    end
  end
end
