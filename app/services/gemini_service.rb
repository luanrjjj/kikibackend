class GeminiService
  BASE_URL = "https://generativelanguage.googleapis.com"

  def self.generate_cards(question_text, context_text, correct_answer)
    api_key = ENV['GEMINI_API_KEY']
    if api_key.blank?
      Rails.logger.error "Gemini API Key is missing!"
      return nil
    end

    # Usando o modelo confirmado pelo diagnóstico (Gemini 2.5 Flash)
    model = "gemini-2.5-flash"
    endpoint = "/v1beta/models/#{model}:generateContent"

    prompt = <<~PROMPT
      Você é um especialista em criação de flashcards para o Anki.
      Sua tarefa é extrair conceitos-chave de uma questão de concurso e transformá-los em flashcards atômicos (curtos e diretos).
      
      Dados da Questão:
      - Texto de Apoio: #{context_text || 'Não fornecido'}
      - Enunciado: #{question_text}
      - Resposta/Gabarito Correto: #{correct_answer || 'Não fornecido'}
      
      Diretrizes para os Flashcards:
      1. Crie entre 2 a 5 flashcards.
      2. Foque em conceitos, definições, prazos ou regras importantes extraídas da questão.
      3. Use o formato de Pergunta e Resposta (Frente e Verso).
      4. As perguntas devem ser curtas e diretas.
      5. As respostas devem ser concisas.
      Retorne APENAS um JSON puro no formato: [{ "front": "...", "back": "..." }]
    PROMPT

    payload = {
      contents: [{
        parts: [{ text: prompt }]
      }]
    }

    begin
      conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post("#{endpoint}?key=#{api_key}", payload)

      if response.success?
        result_text = response.body.dig('candidates', 0, 'content', 'parts', 0, 'text')
        json_match = result_text.match(/\[\s*\{.*\}\s*\]/m)
        json_text = json_match ? json_match[0] : result_text.gsub(/```json|```/, '').strip
        JSON.parse(json_text)
      else
        Rails.logger.error "Gemini API Error Status: #{response.status}"
        Rails.logger.error "Gemini API Error Body: #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "Gemini Service Exception: #{e.message}"
      nil
    end
  end
end
