module Mcp
  # Ferramentas (tools) do servidor MCP. Todas são só de leitura e respondem com
  # dados do usuário dono do token.
  #
  # Cada ferramenta tem uma definição (nome, descrição, JSON Schema dos
  # argumentos), que Mcp::Servidor transforma em MCP::Tool, e um método com o
  # mesmo nome. Os números vêm do EstatisticasService, o mesmo usado pela
  # página de estatísticas do site.
  class Ferramentas
    class ErroDeFerramenta < StandardError; end

    MAX_IDS_ANKI = McpCotaDiaria::MAX_POR_CHAMADA
    MAX_DIAS = 3650
    QUANTIDADE_PADRAO = 20
    SITUACOES = %w[todas nao_respondidas erradas acertadas].freeze

    PERIODO = {
      dias: {
        type: 'integer', minimum: 1, maximum: MAX_DIAS,
        description: 'Quantos dias para trás considerar (padrão 30). Ignorado se data_inicio e data_fim forem enviadas.'
      },
      data_inicio: { type: 'string', format: 'date', description: 'Início do período, AAAA-MM-DD.' },
      data_fim: { type: 'string', format: 'date', description: 'Fim do período, AAAA-MM-DD.' }
    }.freeze

    DEFINICOES = [
      {
        name: 'listar_cadernos',
        title: 'Listar cadernos',
        description: 'Lista os cadernos de questões do usuário, com pasta, total de questões, respondidas, acertos, erros e taxa de acerto.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false }
      },
      {
        name: 'estatisticas_caderno',
        title: 'Estatísticas de um caderno',
        description: 'Desempenho em um caderno, por disciplina, assunto e tópico, considerando a resolução mais recente de cada questão. Use listar_cadernos para obter o caderno_id.',
        inputSchema: {
          type: 'object',
          properties: {
            caderno_id: { type: 'integer', description: 'Id do caderno.' },
            incluir_ids_questoes: { type: 'boolean', description: 'Inclui os ids das questões de cada assunto e tópico (padrão false).' }
          },
          required: ['caderno_id'],
          additionalProperties: false
        }
      },
      {
        name: 'questoes_do_caderno',
        title: 'Questões de um caderno',
        description: "Dados completos das questões de um caderno do usuário, na ordem do caderno, para revisar ou criar flashcards: " \
                     'enunciado, texto de apoio, alternativas, gabarito, classificação, banca, ano e histórico do usuário. ' \
                     "Paginado: até #{McpCotaDiaria::MAX_POR_CHAMADA} questões por chamada (quantidade) e pagina (1, 2, 3...) ou inicio (posição, a partir de 0). " \
                     'A resposta traz paginacao.proxima_pagina e paginacao.proximo_inicio enquanto houver mais. ' \
                     "Cada questão entregue conta na cota de #{McpCotaDiaria::LIMITE_DIARIO} questões por dia (ver cota na resposta). " \
                     'Use listar_cadernos para obter o caderno_id.',
        inputSchema: {
          type: 'object',
          properties: {
            caderno_id: { type: 'integer', description: 'Id do caderno.' },
            quantidade: {
              type: 'integer', minimum: 1, maximum: McpCotaDiaria::MAX_POR_CHAMADA,
              description: "Quantas questões devolver nesta chamada (padrão #{QUANTIDADE_PADRAO}, máximo #{McpCotaDiaria::MAX_POR_CHAMADA})."
            },
            pagina: { type: 'integer', minimum: 1, description: 'Página, começando em 1, com o tamanho de quantidade (padrão 1).' },
            inicio: { type: 'integer', minimum: 0, description: 'Posição da primeira questão, a partir de 0. Se enviado, tem prioridade sobre pagina.' },
            situacao: {
              type: 'string', enum: SITUACOES,
              description: 'Filtra pela resolução mais recente do usuário neste caderno: todas (padrão), nao_respondidas, erradas ou acertadas.'
            },
            incluir_comentarios: { type: 'boolean', description: 'Inclui até 3 comentários mais votados de cada questão (padrão false).' }
          },
          required: ['caderno_id'],
          additionalProperties: false
        }
      },
      {
        name: 'estatisticas_gerais',
        title: 'Estatísticas gerais',
        description: 'Resumo do período (resoluções, acertos, erros, taxa de acerto, dias com estudo), desempenho por disciplina e evolução por dia.',
        inputSchema: { type: 'object', properties: PERIODO, additionalProperties: false }
      },
      {
        name: 'desempenho_por_assunto',
        title: 'Desempenho por assunto',
        description: 'Desempenho em árvore disciplina > assunto > tópico no período, da maior para a menor taxa de acerto. Depende do plano do usuário.',
        inputSchema: {
          type: 'object',
          properties: PERIODO.merge(disciplina_id: { type: 'integer', description: 'Restringe a uma disciplina.' }),
          additionalProperties: false
        }
      },
      {
        name: 'pontos_fracos',
        title: 'Pontos fracos',
        description: 'Assuntos com a pior taxa de acerto no período, ignorando os que têm poucas resoluções.',
        inputSchema: {
          type: 'object',
          properties: PERIODO.merge(
            limite: { type: 'integer', minimum: 1, maximum: 50, description: 'Quantos assuntos devolver (padrão 10).' },
            minimo_resolucoes: { type: 'integer', minimum: 1, maximum: 500, description: 'Mínimo de resoluções para o assunto entrar na lista (padrão 5).' },
            disciplina_id: { type: 'integer', description: 'Restringe a uma disciplina.' }
          ),
          additionalProperties: false
        }
      },
      {
        name: 'questoes_erradas',
        title: 'Questões erradas',
        description: 'Questões que o usuário errou ao menos uma vez, da mais recente para a mais antiga, com disciplina, assunto, número de tentativas e se a última tentativa foi acerto. Sem período, considera todo o histórico. Use os ids em questoes_para_anki.',
        inputSchema: {
          type: 'object',
          properties: PERIODO.merge(
            caderno_id: { type: 'integer', description: 'Só as resoluções deste caderno.' },
            apenas_pendentes: { type: 'boolean', description: 'Só as questões cuja última tentativa ainda foi erro (padrão false).' },
            limite: { type: 'integer', minimum: 1, maximum: 200, description: 'Máximo de questões (padrão 50).' }
          ),
          additionalProperties: false
        }
      },
      {
        name: 'questoes_para_anki',
        title: 'Questões para flashcards',
        description: "Dados completos de até #{MAX_IDS_ANKI} questões para criar flashcards: enunciado, texto de apoio, alternativas, gabarito, disciplina, assunto, tópico, banca, ano, histórico do usuário e, opcionalmente, os comentários mais votados. " \
                     "Cada questão entregue conta na cota de #{McpCotaDiaria::LIMITE_DIARIO} questões por dia. Para as questões de um caderno, prefira questoes_do_caderno.",
        inputSchema: {
          type: 'object',
          properties: {
            ids: { type: 'array', items: { type: 'integer' }, minItems: 1, maxItems: MAX_IDS_ANKI, description: 'Ids das questões.' },
            incluir_comentarios: { type: 'boolean', description: 'Inclui até 3 comentários mais votados de cada questão (padrão false).' }
          },
          required: ['ids'],
          additionalProperties: false
        }
      }
    ].freeze

    NOMES = DEFINICOES.map { |d| d[:name] }.freeze

    def initialize(user)
      @user = user
    end

    def existe?(nome)
      NOMES.include?(nome)
    end

    # @return [Hash]
    def chamar(nome, argumentos)
      raise ErroDeFerramenta, "Ferramenta desconhecida: #{nome}" unless existe?(nome)

      public_send(nome, argumentos.transform_keys(&:to_s))
    end

    # -------------------------------------------------------------------------

    def listar_cadernos(_args)
      cadernos = @user.cadernos.includes(:pasta_caderno).order(created_at: :desc).to_a
      contagens = estatisticas.contagens_por_caderno(cadernos.map(&:id))

      lista = cadernos.map do |c|
        cont = contagens[c.id]
        {
          id: c.id,
          nome: c.nome,
          pasta: c.pasta_caderno&.nome,
          total_questoes: Array(c.questoes_ids).length,
          respondidas: cont[:respondidas],
          acertos: cont[:acertos],
          erros: cont[:erros],
          taxa_acerto: EstatisticasService.taxa(cont[:acertos], cont[:acertos] + cont[:erros]),
          criado_em: c.created_at&.to_date&.iso8601
        }
      end

      { total: lista.length, cadernos: lista, cota: cota.resumo }
    end

    def estatisticas_caderno(args)
      caderno_id = inteiro(args['caderno_id'], 'caderno_id', obrigatorio: true)
      caderno = @user.cadernos.find_by(id: caderno_id)
      raise ErroDeFerramenta, "Caderno #{caderno_id} não encontrado entre os cadernos do usuário. Use listar_cadernos." unless caderno

      dados = estatisticas.caderno(caderno)
      incluir_ids = verdadeiro?(args['incluir_ids_questoes'])
      resumo = (dados[:summary] || {}).to_h.transform_values(&:to_i)

      {
        caderno: { id: caderno.id, nome: caderno.nome, total_questoes: Array(caderno.questoes_ids).length },
        resumo: resumo.merge('taxa_acerto' => EstatisticasService.taxa(resumo['total_acertos'], resumo['total_resolucoes'])),
        questoes_resolvidas: Array(dados[:resolvidas_ids]).uniq.length,
        disciplinas: Array(dados[:hierarchy]).map { |d| no_do_caderno(d, incluir_ids) }
      }
    end

    def estatisticas_gerais(args)
      inicio, fim = periodo(args)

      {
        periodo: periodo_json(inicio, fim),
        resumo: estatisticas.resumo(inicio, fim),
        por_disciplina: estatisticas.por_disciplina(inicio, fim).map { |r| com_taxa(r) },
        por_dia: estatisticas.por_dia(inicio, fim).map { |r| com_taxa(r).merge('date' => r['date'].to_s) }
      }
    end

    def desempenho_por_assunto(args)
      unless @user.pode?('show_stats_table_by_assunto_basic')
        raise ErroDeFerramenta, 'O plano do usuário não inclui estatísticas por assunto e tópico. Use pontos_fracos ou estatisticas_gerais, ou assine um plano no Apolo.'
      end

      inicio, fim = periodo(args)
      disciplina_id = inteiro(args['disciplina_id'], 'disciplina_id')

      arvore = estatisticas.hierarquia(inicio, fim)
      arvore = arvore.select { |d| d[:id].to_i == disciplina_id } if disciplina_id

      {
        periodo: periodo_json(inicio, fim),
        disciplinas: arvore.map do |d|
          no_com_taxa(d).merge(
            assuntos: d[:assuntos].map do |a|
              no_com_taxa(a).merge(topicos: a[:topicos].map { |t| no_com_taxa(t) })
            end
          )
        end
      }
    end

    def pontos_fracos(args)
      inicio, fim = periodo(args)
      limite = (inteiro(args['limite'], 'limite') || 10).clamp(1, 50)
      minimo = (inteiro(args['minimo_resolucoes'], 'minimo_resolucoes') || 5).clamp(1, 500)

      assuntos = estatisticas.pontos_fracos(
        inicio, fim,
        limite: limite,
        minimo_resolucoes: minimo,
        disciplina_id: inteiro(args['disciplina_id'], 'disciplina_id')
      )

      {
        periodo: periodo_json(inicio, fim),
        minimo_resolucoes: minimo,
        assuntos: assuntos.map do |r|
          {
            disciplina_id: r['disciplina_id'], disciplina: r['disciplina_nome'],
            assunto_id: r['assunto_id'], assunto: r['assunto_nome'],
            total_resolucoes: r['total_resolucoes'].to_i,
            acertos: r['total_acertos'].to_i,
            erros: r['total_erros'].to_i,
            taxa_acerto: r['taxa_acerto']
          }
        end
      }
    end

    def questoes_erradas(args)
      caderno_id = inteiro(args['caderno_id'], 'caderno_id')
      if caderno_id && !@user.cadernos.exists?(id: caderno_id)
        raise ErroDeFerramenta, "Caderno #{caderno_id} não encontrado entre os cadernos do usuário."
      end

      com_periodo = args['dias'].present? || (args['data_inicio'].present? && args['data_fim'].present?)
      inicio, fim = com_periodo ? periodo(args) : [nil, nil]
      limite = (inteiro(args['limite'], 'limite') || 50).clamp(1, 200)

      linhas = estatisticas.questoes_erradas(
        inicio: inicio, fim: fim,
        caderno_id: caderno_id,
        limite: limite,
        apenas_pendentes: verdadeiro?(args['apenas_pendentes'])
      )

      {
        periodo: com_periodo ? periodo_json(inicio, fim) : 'todo o histórico',
        total: linhas.length,
        questoes: linhas.map do |r|
          {
            id: r['questao_id'],
            disciplina: r['disciplina_nome'],
            assunto: r['assunto_nome'],
            topico: r['topico_nome'],
            ano: r['ano'],
            tentativas: r['tentativas'].to_i,
            erros: r['erros'].to_i,
            ultima_resposta: r['ultima_resposta'],
            ultima_correta: ActiveModel::Type::Boolean.new.cast(r['ultima_correta']),
            ultima_resolucao_em: r['ultima_resolucao_em'].to_s
          }
        end
      }
    end

    def questoes_para_anki(args)
      ids = AnkiQuestoesService.normalizar_ids(args['ids'])
      raise ErroDeFerramenta, 'Informe ao menos um id em ids.' if ids.empty?
      if ids.length > MAX_IDS_ANKI
        raise ErroDeFerramenta, "Envie no máximo #{MAX_IDS_ANKI} ids por chamada (recebidos: #{ids.length})."
      end

      entregar_com_cota(ids, incluir_comentarios: verdadeiro?(args['incluir_comentarios'])) do |resultado, nao_entregues|
        dados = resultado.merge(nao_entregues_pela_cota: nao_entregues)
        if nao_entregues.any?
          dados[:mensagem] = "Cota diária atingida: #{nao_entregues.length} questões ficaram para amanhã (ver nao_entregues_pela_cota)."
        end
        dados
      end
    end

    def questoes_do_caderno(args)
      caderno_id = inteiro(args['caderno_id'], 'caderno_id', obrigatorio: true)
      caderno = @user.cadernos.find_by(id: caderno_id)
      raise ErroDeFerramenta, "Caderno #{caderno_id} não encontrado entre os cadernos do usuário. Use listar_cadernos." unless caderno

      quantidade = (inteiro(args['quantidade'], 'quantidade') || QUANTIDADE_PADRAO).clamp(1, McpCotaDiaria::MAX_POR_CHAMADA)
      pagina = [inteiro(args['pagina'], 'pagina') || 1, 1].max
      inicio = inteiro(args['inicio'], 'inicio')
      inicio = inicio.nil? ? (pagina - 1) * quantidade : [inicio, 0].max

      situacao = (args['situacao'].presence || 'todas').to_s
      unless SITUACOES.include?(situacao)
        raise ErroDeFerramenta, "situacao deve ser uma de: #{SITUACOES.join(', ')} (recebido: #{situacao.inspect})."
      end

      todos_ids = filtrar_por_situacao(caderno, AnkiQuestoesService.normalizar_ids(Array(caderno.questoes_ids)), situacao)
      ids_da_pagina = todos_ids[inicio, quantidade] || []

      base = {
        caderno: { id: caderno.id, nome: caderno.nome, total_questoes: Array(caderno.questoes_ids).length },
        situacao: situacao
      }

      if ids_da_pagina.empty?
        return base.merge(
          total: 0, questoes: [], nao_encontradas: [],
          paginacao: self.class.paginacao(total: todos_ids.length, inicio: inicio, quantidade: quantidade, entregues: 0),
          cota: cota.resumo,
          mensagem: todos_ids.empty? ? 'Nenhuma questão do caderno nesta situação.' : 'Não há mais questões a partir desta posição.'
        )
      end

      entregar_com_cota(ids_da_pagina, incluir_comentarios: verdadeiro?(args['incluir_comentarios'])) do |resultado, nao_entregues|
        entregues = ids_da_pagina.length - nao_entregues.length
        dados = base.merge(resultado).merge(
          paginacao: self.class.paginacao(total: todos_ids.length, inicio: inicio, quantidade: quantidade, entregues: entregues)
        )
        if nao_entregues.any?
          dados[:mensagem] = "Cota diária atingida: foram entregues #{entregues} de #{ids_da_pagina.length} questões. " \
                             "Continue amanhã com inicio=#{inicio + entregues}."
        end
        dados
      end
    end

    # Metadados de paginação. proxima_pagina só aparece quando a próxima posição
    # cai no começo de uma página do mesmo tamanho; proximo_inicio sempre vale.
    def self.paginacao(total:, inicio:, quantidade:, entregues:)
      proximo = inicio + entregues
      tem_mais = entregues.positive? && proximo < total
      {
        total: total,
        quantidade: quantidade,
        inicio: inicio,
        entregues: entregues,
        pagina: (inicio / quantidade) + 1,
        total_paginas: (total.to_f / quantidade).ceil,
        tem_mais: tem_mais,
        proximo_inicio: tem_mais ? proximo : nil,
        proxima_pagina: tem_mais && (proximo % quantidade).zero? ? (proximo / quantidade) + 1 : nil
      }
    end

    private

    def estatisticas
      @estatisticas ||= EstatisticasService.new(@user)
    end

    def cota
      @cota ||= McpCotaDiaria.new(@user)
    end

    # Reserva a cota, busca as questões e devolve à cota as que não existem.
    # Entrega só as que couberem na cota de hoje; as demais vão para o bloco
    # como nao_entregues.
    def entregar_com_cota(ids, incluir_comentarios:)
      concedidas = cota.reservar!(ids.length)
      entregar = ids.first(concedidas)

      resultado = AnkiQuestoesService.new(@user, incluir_comentarios: incluir_comentarios, max_ids: MAX_IDS_ANKI).buscar(entregar)
      cota.devolver!(resultado[:nao_encontradas].length)

      dados = yield(resultado, ids.drop(concedidas))
      dados.merge(cota: cota.resumo)
    rescue McpCotaDiaria::Esgotada => e
      raise ErroDeFerramenta, e.message
    rescue AnkiQuestoesService::LimiteExcedido => e
      raise ErroDeFerramenta, e.message
    end

    # Mantém a ordem do caderno. A situação considera a resolução mais recente
    # do usuário em cada questão, dentro deste caderno (como estatisticas_caderno).
    def filtrar_por_situacao(caderno, ids, situacao)
      return ids if situacao == 'todas' || ids.empty?

      ultimas = Resolucao.where(user_id: @user.id, caderno_id: caderno.id, questao_id: ids)
                         .select('DISTINCT ON (questao_id) questao_id, correta')
                         .order(Arel.sql('questao_id, created_at DESC'))
                         .to_a
                         .to_h { |r| [r.questao_id, r.correta] }

      case situacao
      when 'nao_respondidas' then ids.reject { |id| ultimas.key?(id) }
      when 'erradas' then ids.select { |id| ultimas.key?(id) && ultimas[id] == false }
      when 'acertadas' then ids.select { |id| ultimas[id] == true }
      else ids
      end
    end

    def periodo(args)
      inicio = data(args['data_inicio'], 'data_inicio')
      fim = data(args['data_fim'], 'data_fim')
      if (inicio.nil? ^ fim.nil?)
        raise ErroDeFerramenta, 'Envie data_inicio e data_fim juntas, ou use dias.'
      end
      raise ErroDeFerramenta, 'data_inicio deve ser anterior ou igual a data_fim.' if inicio && fim && inicio > fim

      dias = inteiro(args['dias'], 'dias')
      dias = dias.clamp(1, MAX_DIAS) if dias
      EstatisticasService.periodo(days: dias, start_date: inicio, end_date: fim)
    end

    def periodo_json(inicio, fim)
      { inicio: inicio.to_date.iso8601, fim: fim.to_date.iso8601 }
    end

    def data(valor, nome)
      return nil if valor.blank?

      Date.iso8601(valor.to_s)
    rescue ArgumentError
      raise ErroDeFerramenta, "#{nome} deve estar no formato AAAA-MM-DD (recebido: #{valor.inspect})."
    end

    def inteiro(valor, nome, obrigatorio: false)
      if valor.nil? || valor.to_s.strip.empty?
        raise ErroDeFerramenta, "#{nome} é obrigatório." if obrigatorio

        return nil
      end

      numero = Integer(valor.to_s, exception: false)
      raise ErroDeFerramenta, "#{nome} deve ser um número inteiro (recebido: #{valor.inspect})." if numero.nil?

      numero
    end

    def verdadeiro?(valor)
      ActiveModel::Type::Boolean.new.cast(valor) == true
    end

    def com_taxa(row)
      row.merge('taxa_acerto' => EstatisticasService.taxa(row['total_acertos'], row['total_resolucoes']))
    end

    def no_com_taxa(no)
      {
        id: no[:id],
        nome: no[:name],
        total_resolucoes: no[:total_resolucoes],
        acertos: no[:acertos],
        erros: no[:erros],
        taxa_acerto: EstatisticasService.taxa(no[:acertos], no[:total_resolucoes])
      }
    end

    def no_do_caderno(no, incluir_ids)
      dados = {
        id: no[:id],
        nome: no[:name],
        total_questoes: no[:total_questoes],
        resolvidas: no[:total_resolvidas],
        acertos: no[:acertos],
        erros: no[:erros],
        taxa_acerto: EstatisticasService.taxa(no[:acertos], no[:total_resolvidas])
      }
      dados[:ids_questoes] = no[:questao_ids] if incluir_ids && no[:questao_ids]
      dados[:assuntos] = no[:assuntos].map { |a| no_do_caderno(a, incluir_ids) } if no[:assuntos]
      dados[:topicos] = no[:topicos].map { |t| no_do_caderno(t, incluir_ids) } if no[:topicos].present?
      dados
    end
  end
end
