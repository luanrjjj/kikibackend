class AiService
  CHAVES_FRENTE = %w[front frente pergunta question].freeze
  CHAVES_VERSO = %w[back verso resposta answer].freeze

  # Sempre devolve um Array de { 'front' => ..., 'back' => ... } (ou nil se a
  # IA falhou ou não gerou nenhum card válido).
  def self.generate_cards(question_text, context_text, correct_answer)
    provider = ConfigGlobalApolo.get('ai_api_name', 'gemini').downcase

    resposta =
      case provider
      when 'deepseek'
        DeepSeekService.generate_cards(question_text, context_text, correct_answer)
      else
        GeminiService.generate_cards(question_text, context_text, correct_answer)
      end

    cards = normalizar_cards(resposta)
    if cards.empty?
      Rails.logger.error "AiService: resposta da IA (#{provider}) sem cards válidos: #{resposta.inspect.truncate(500)}"
      return nil
    end

    cards
  end

  # Converte o que a IA (ou o cache em questaos.ia_conceito_extracao) devolveu
  # em uma lista de cards. Aceita:
  #   [{ "front": "...", "back": "..." }, ...]
  #   { "cards": [...] } / { "flashcards": [...] } / qualquer chave com a lista
  #   { "front": "...", "back": "..." }  (um card só)
  #   String com qualquer um dos formatos acima em JSON
  def self.normalizar_cards(valor)
    valor = JSON.parse(valor) if valor.is_a?(String)
    lista = extrair_lista(valor)

    lista.filter_map do |card|
      next unless card.is_a?(Hash)

      card = card.transform_keys { |k| k.to_s.downcase }
      frente = card.values_at(*CHAVES_FRENTE).find(&:present?)
      verso = card.values_at(*CHAVES_VERSO).find(&:present?)
      next if frente.blank? || verso.blank?

      { 'front' => frente.to_s.strip, 'back' => verso.to_s.strip }
    end
  rescue JSON::ParserError
    []
  end

  def self.extrair_lista(valor)
    case valor
    when Array
      valor
    when Hash
      chaves = valor.keys.map { |k| k.to_s.downcase }
      return [valor] if (chaves & CHAVES_FRENTE).any? && (chaves & CHAVES_VERSO).any?

      valor.values.find { |v| v.is_a?(Array) } ||
        valor.values.lazy.map { |v| extrair_lista(v) }.find(&:present?) ||
        []
    else
      []
    end
  end
  private_class_method :extrair_lista
end
