# Monta os dados de questões no formato usado para criar flashcards (Anki)
# com a IA do próprio usuário.
#
# Usado por:
# - GET/POST /api/anki/questoes (AnkiQuestoesController)
# - ferramenta questoes_para_anki do MCP
#
# Cada questão traz enunciado (HTML e texto puro), texto de apoio,
# alternativas, gabarito, classificação (disciplina > assunto > tópico),
# origem (banca, órgão, ano, prova), o histórico do usuário nela e, se
# pedido, os comentários mais votados.
class AnkiQuestoesService
  MAX_IDS = 100
  MAX_COMENTARIOS = 5

  class LimiteExcedido < StandardError; end

  # Converte "1,2,3", [1, "2"], "4" etc. em uma lista de inteiros positivos,
  # sem repetição e na ordem recebida.
  def self.normalizar_ids(valor)
    lista = valor.is_a?(Array) ? valor : valor.to_s.split(/[\s,;]+/)
    lista.flat_map { |v| v.is_a?(String) ? v.split(/[\s,;]+/) : [v] }
         .map { |v| Integer(v.to_s, exception: false) }
         .compact
         .select(&:positive?)
         .uniq
  end

  def self.html_para_texto(html)
    return nil if html.blank?

    Loofah.html5_fragment(html.to_s).to_text(encode_special_chars: false)
          .gsub(/ /, ' ')
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
  rescue StandardError
    html.to_s.gsub(/<br\s*\/?>/i, "\n").gsub(/<[^>]+>/, '').squeeze(' ').strip
  end

  def initialize(user, incluir_comentarios: false, limite_comentarios: 3, max_ids: MAX_IDS)
    @user = user
    @incluir_comentarios = incluir_comentarios
    @limite_comentarios = limite_comentarios.to_i.clamp(1, MAX_COMENTARIOS)
    @max_ids = max_ids
  end

  # @param ids [Array<Integer>]
  # @return [Hash] { total:, questoes: [...], nao_encontradas: [...] }
  def buscar(ids)
    ids = self.class.normalizar_ids(ids)
    raise LimiteExcedido, "Envie no máximo #{@max_ids} ids por requisição (recebidos: #{ids.length})." if ids.length > @max_ids

    return { total: 0, questoes: [], nao_encontradas: [] } if ids.empty?

    questoes = Questao.where(id: ids)
                      .includes(:disciplina, :assunto, :topico, :texto, { provas: [:banca, :orgao, :concurso] }, concurso: [:banca, :orgao])
                      .index_by { |q| q[:id] }

    encontrados = ids.select { |id| questoes.key?(id) }
    resolucoes = resolucoes_do_usuario(encontrados)
    comentarios = @incluir_comentarios ? comentarios_mais_votados(encontrados) : {}

    lista = encontrados.map do |id|
      formatar(questoes[id], resolucoes[id], comentarios[id])
    end

    { total: lista.length, questoes: lista, nao_encontradas: ids - encontrados }
  end

  private

  def formatar(questao, resolucoes, comentarios)
    prova = questao.provas.first
    concurso = questao.concurso || prova&.concurso
    banca = concurso&.banca || prova&.banca
    orgao = concurso&.orgao || prova&.orgao
    alternativas = Array(questao.alternativas)
    gabarito = questao.correta.presence
    alternativa_correta = alternativas.find { |a| valor_alternativa(a) == gabarito }

    dados = {
      id: questao[:id],
      tipo: tipo(questao, alternativas),
      ano: questao.ano,
      banca: banca && { nome: banca.nome, sigla: banca.try(:sigla) },
      orgao: orgao && { nome: orgao.nome, sigla: orgao.try(:sigla) },
      concurso: (concurso && !concurso.try(:is_blocked)) ? concurso.nome : nil,
      prova: (prova && !prova.is_blocked) ? prova.nome : nil,
      disciplina: questao.disciplina&.nome,
      assunto: questao.assunto&.nome,
      topico: questao.topico&.nome,
      anulada: questao.anulada.present?,
      desatualizada: questao.desatualizada.present?,
      texto_apoio: self.class.html_para_texto(questao.texto&.texto),
      texto_apoio_imagem: questao.texto&.imagem_texto.presence,
      enunciado: self.class.html_para_texto(questao.enunciado),
      enunciado_html: questao.enunciado,
      alternativas: alternativas.map do |a|
        valor = valor_alternativa(a)
        {
          letra: valor,
          texto: self.class.html_para_texto(texto_alternativa(a)),
          correta: gabarito.present? && valor == gabarito
        }
      end,
      gabarito: gabarito && {
        letra: gabarito,
        texto: self.class.html_para_texto(alternativa_correta && texto_alternativa(alternativa_correta))
      },
      cards_ia_existentes: AiService.normalizar_cards(questao.ia_conceito_extracao).presence,
      minha_resolucao: resumo_resolucoes(resolucoes)
    }

    dados[:comentarios] = comentarios || [] if @incluir_comentarios
    dados
  end

  def tipo(questao, alternativas)
    return 'discursiva' if questao.discursiva
    valores = alternativas.map { |a| valor_alternativa(a).to_s.upcase }.sort
    return 'certo_errado' if valores == %w[C E]

    'multipla_escolha'
  end

  def valor_alternativa(alternativa)
    return alternativa.to_s unless alternativa.is_a?(Hash)

    (alternativa['value'] || alternativa[:value] || alternativa['letra'] || alternativa[:letra]).to_s
  end

  def texto_alternativa(alternativa)
    return alternativa.to_s unless alternativa.is_a?(Hash)

    alternativa['text'] || alternativa[:text] || alternativa['texto'] || alternativa[:texto]
  end

  # { questao_id => [[correta, resposta, created_at], ...] } da mais recente para a mais antiga
  def resolucoes_do_usuario(ids)
    return {} if ids.empty? || @user.nil?

    @user.resolucoes.originais
         .where(questao_id: ids)
         .order(created_at: :desc)
         .pluck(:questao_id, :correta, :resposta, :created_at)
         .group_by(&:first)
         .transform_values { |linhas| linhas.map { |l| l.drop(1) } }
  end

  def resumo_resolucoes(linhas)
    return { respondida: false, tentativas: 0, erros: 0 } if linhas.blank?

    ultima_correta, ultima_resposta, ultima_em = linhas.first
    {
      respondida: true,
      tentativas: linhas.length,
      erros: linhas.count { |l| l[0] == false },
      ultima_resposta: ultima_resposta,
      ultima_correta: ultima_correta,
      ultima_resolucao_em: ultima_em
    }
  end

  # Os comentários mais votados de cada questão. Não inclui o nome de quem
  # escreveu.
  def comentarios_mais_votados(ids)
    return {} if ids.empty?

    ranqueados = Comentario.where(questao_id: ids).select(
      'comentarios.questao_id, comentarios.texto, comentarios.votos_soma, comentarios.created_at, ' \
      'ROW_NUMBER() OVER (PARTITION BY comentarios.questao_id ORDER BY comentarios.votos_soma DESC, comentarios.created_at ASC) AS posicao'
    )

    Comentario.unscoped
              .from(ranqueados, :comentarios)
              .where('posicao <= ?', @limite_comentarios)
              .order(:questao_id, :posicao)
              .pluck(:questao_id, :texto, :votos_soma)
              .group_by(&:first)
              .transform_values do |linhas|
                linhas.map { |_, texto, votos| { texto: self.class.html_para_texto(texto), votos: votos.to_i } }
              end
  end
end
