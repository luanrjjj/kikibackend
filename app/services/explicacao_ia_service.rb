# Explicação de uma questão por IA (kikiapps#22).
#
# A primeira vez que alguém pede a explicação de uma questão, o provedor (hoje
# só o DeepSeek) é chamado e a resposta fica salva na coluna do provedor em
# questaos (deepseek_explicacao). Dali em diante, todo mundo recebe a resposta
# salva, sem chamar a IA de novo.
#
# Para incluir outro provedor: uma coluna <provedor>_explicacao em questaos e
# uma entrada em PROVEDORES com um objeto que responda a chat_json(prompt).
class ExplicacaoIaService
  PROVEDORES = {
    'deepseek' => { coluna: :deepseek_explicacao, nome: 'DeepSeek', servico: -> { DeepSeekService }, modelo: -> { DeepSeekService::MODELO } }
  }.freeze
  PROVEDOR_PADRAO = 'deepseek'.freeze

  # Explicações novas (que chamam a IA) por usuário por dia. As já salvas não contam.
  LIMITE_GERACOES_POR_DIA = 30
  VERSAO_FORMATO = 1

  class Erro < StandardError
    attr_reader :status

    def initialize(mensagem, status = :unprocessable_entity)
      super(mensagem)
      @status = status
    end
  end

  def self.provedor_valido?(provedor)
    PROVEDORES.key?(provedor.to_s)
  end

  def initialize(questao, user:, provedor: PROVEDOR_PADRAO)
    @questao = questao
    @user = user
    @provedor = provedor.to_s.presence || PROVEDOR_PADRAO
    raise Erro.new("Provedor de IA desconhecido: #{@provedor}.", :bad_request) unless self.class.provedor_valido?(@provedor)

    @config = PROVEDORES.fetch(@provedor)
  end

  # @param regenerar [Boolean] só admin: ignora a explicação salva e gera de novo
  # @return [Hash]
  def call(regenerar: false)
    regenerar &&= @user&.admin?
    salva = explicacao_salva

    if salva && !regenerar
      return resposta(salva, gerada_agora: false)
    end

    limitar_geracoes!
    gerada = gerar
    raise Erro.new('Não foi possível gerar a explicação agora. Tente de novo em instantes.', :service_unavailable) unless gerada

    resposta(salvar(gerada, sobrescrever: regenerar), gerada_agora: true)
  end

  # Registra (ou troca) a avaliação do usuário.
  def avaliar!(util)
    valor = ActiveModel::Type::Boolean.new.cast(util)
    raise Erro.new('Informe util: true ou false.', :bad_request) if valor.nil?
    raise Erro.new('Esta questão ainda não tem explicação por IA.', :not_found) unless explicacao_salva

    avaliacao = ExplicacaoIaAvaliacao.find_or_initialize_by(user: @user, questao: @questao, provedor: @provedor)
    avaliacao.update!(util: valor)
    { provedor: @provedor, avaliacao: valor, avaliacoes: contagem_avaliacoes }
  end

  # Prompt enviado à IA. Público para facilitar teste e ajuste.
  def prompt
    alternativas = Array(@questao.alternativas).map do |a|
      letra, texto = letra_e_texto(a)
      "#{letra}) #{texto}"
    end
    gabarito = @questao.correta.presence
    texto_apoio = AnkiQuestoesService.html_para_texto(@questao.texto&.texto)

    <<~PROMPT
      Você é um professor experiente de cursinho preparatório para concursos públicos no Brasil.
      Explique a questão abaixo para um aluno, em português do Brasil, de forma clara, correta e objetiva.

      Disciplina: #{@questao.disciplina&.nome || 'não informada'}
      Assunto: #{@questao.assunto&.nome || 'não informado'}
      Tipo: #{tipo_questao}
      #{"Texto de apoio:\n#{texto_apoio}\n" if texto_apoio.present?}
      Enunciado:
      #{AnkiQuestoesService.html_para_texto(@questao.enunciado)}

      #{alternativas.any? ? "Alternativas:\n#{alternativas.join("\n")}" : 'Questão sem alternativas (discursiva).'}

      Gabarito oficial: #{gabarito || 'não informado'}
      #{'Atenção: esta questão foi ANULADA pela banca; explique o provável motivo da anulação.' if @questao.anulada.present?}
      #{'Atenção: esta questão está DESATUALIZADA; avise o que mudou, se souber.' if @questao.desatualizada.present?}

      Regras:
      1. Considere o gabarito oficial como correto. Se ele não foi informado, diga qual é a resposta mais provável e deixe claro que é uma análise.
      2. Não invente leis, artigos, súmulas ou jurisprudência. Cite a fonte só quando tiver certeza.
      3. Comente TODAS as alternativas, dizendo por que cada uma está certa ou errada.
      4. Seja direto: frases curtas, sem repetir o enunciado.

      Retorne APENAS um objeto JSON neste formato:
      {
        "resumo": "o que a questão cobra, em 1 ou 2 frases",
        "gabarito": "letra da resposta correta (ou C/E)",
        "explicacao": "por que a resposta correta está certa, em até 3 parágrafos curtos separados por \\n\\n",
        "alternativas": [{ "letra": "A", "correta": false, "comentario": "por que está errada" }],
        "conceitos": ["conceito-chave 1", "conceito-chave 2"],
        "dica": "pegadinha ou macete para não errar questões parecidas (opcional)"
      }
    PROMPT
  end

  # Normaliza o JSON da IA no formato salvo. Público para teste.
  def self.normalizar(bruto)
    return nil unless bruto.is_a?(Hash)

    bruto = bruto.transform_keys { |k| k.to_s.downcase }
    texto = ->(v, max) { v.is_a?(String) ? v.strip.truncate(max).presence : nil }

    alternativas = Array(bruto['alternativas']).filter_map do |a|
      next unless a.is_a?(Hash)

      a = a.transform_keys { |k| k.to_s.downcase }
      letra = texto.call(a['letra'].to_s, 5)
      comentario = texto.call(a['comentario'] || a['explicacao'], 2000)
      next if letra.blank? || comentario.blank?

      { 'letra' => letra, 'correta' => ActiveModel::Type::Boolean.new.cast(a['correta']) == true, 'comentario' => comentario }
    end

    dados = {
      'resumo' => texto.call(bruto['resumo'], 1000),
      'gabarito' => texto.call(bruto['gabarito'].to_s, 10),
      'explicacao' => texto.call(bruto['explicacao'], 6000),
      'alternativas' => alternativas,
      'conceitos' => Array(bruto['conceitos']).filter_map { |c| texto.call(c, 300) }.first(8),
      'dica' => texto.call(bruto['dica'], 1000)
    }
    return nil if dados['explicacao'].blank? && alternativas.empty?

    dados.compact
  end

  private

  def coluna
    @config[:coluna]
  end

  def explicacao_salva
    valor = @questao.public_send(coluna)
    return nil unless valor.is_a?(Hash)

    valor['explicacao'].present? || valor['alternativas'].present? ? valor : nil
  end

  def gerar
    bruto = @config[:servico].call.chat_json(prompt)
    dados = self.class.normalizar(bruto)
    unless dados
      Rails.logger.error "[ExplicacaoIA] #{@provedor} sem explicação válida para questao=#{@questao.id}: #{bruto.inspect.truncate(500)}"
      return nil
    end

    dados.merge(
      'versao' => VERSAO_FORMATO,
      'modelo' => @config[:modelo].call,
      'gerada_em' => Time.current.iso8601
    )
  end

  # Grava só se a coluna ainda estiver vazia (ou se for regeneração). Se outra
  # requisição salvou antes, usa a dela e descarta esta.
  def salvar(dados, sobrescrever:)
    escopo = Questao.where(id: @questao.id)
    escopo = escopo.where(coluna => nil) unless sobrescrever
    atualizadas = escopo.update_all(coluna => dados, updated_at: Time.current)
    @questao.reload if atualizadas.zero?
    atualizadas.zero? ? (explicacao_salva || dados) : dados
  end

  def limitar_geracoes!
    return if @user.nil? || @user.admin?

    chave = "explicacao_ia:geracoes:#{@user.id}:#{Date.current.iso8601}"
    contagem = Rails.cache.increment(chave, 1, expires_in: 25.hours)
    return if contagem.nil? || contagem <= LIMITE_GERACOES_POR_DIA

    raise Erro.new(
      "Você atingiu o limite de #{LIMITE_GERACOES_POR_DIA} explicações novas por IA hoje. " \
      'Explicações que já existem continuam disponíveis.',
      :too_many_requests
    )
  rescue Erro
    raise
  rescue StandardError => e
    Rails.logger.warn("[ExplicacaoIA] Falha no limite de gerações: #{e.class}: #{e.message}")
  end

  def resposta(explicacao, gerada_agora:)
    {
      provedor: @provedor,
      provedor_nome: @config[:nome],
      questao_id: @questao.id,
      explicacao: explicacao,
      gerada_agora: gerada_agora,
      avaliacao: avaliacao_do_usuario,
      avaliacoes: contagem_avaliacoes
    }
  end

  def avaliacao_do_usuario
    return nil unless @user

    ExplicacaoIaAvaliacao.where(user_id: @user.id, questao_id: @questao.id, provedor: @provedor).pick(:util)
  end

  def contagem_avaliacoes
    contagem = ExplicacaoIaAvaliacao.where(questao_id: @questao.id, provedor: @provedor).group(:util).count
    { uteis: contagem[true].to_i, nao_uteis: contagem[false].to_i }
  end

  def letra_e_texto(alternativa)
    return [alternativa.to_s, ''] unless alternativa.is_a?(Hash)

    letra = alternativa['value'] || alternativa[:value] || alternativa['letra'] || alternativa[:letra]
    texto = alternativa['text'] || alternativa[:text] || alternativa['texto'] || alternativa[:texto]
    [letra.to_s, AnkiQuestoesService.html_para_texto(texto.to_s)]
  end

  def tipo_questao
    return 'discursiva' if @questao.discursiva

    letras = Array(@questao.alternativas).map { |a| letra_e_texto(a).first.upcase }.sort
    letras == %w[C E] ? 'certo ou errado' : 'múltipla escolha'
  end
end
