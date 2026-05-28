class DeepSeekService
  BASE_URL = "https://api.deepseek.com"

  def self.generate_cards(question_text, context_text, correct_answer)
    api_key = ENV['DEEPSEEK_API_KEY']
    if api_key.blank?
      Rails.logger.error "DeepSeek API Key is missing!"
      return nil
    end

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
      model: "deepseek-chat",
      messages: [
        { role: "system", content: "You are a helpful assistant that outputs only JSON." },
        { role: "user", content: prompt }
      ],
      response_format: { type: "json_object" }
    }

    begin
      conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post("/v1/chat/completions") do |req|
        req.headers['Authorization'] = "Bearer #{api_key}"
        req.body = payload
      end

      if response.success?
        content = response.body.dig('choices', 0, 'message', 'content')
        JSON.parse(content)
      else
        Rails.logger.error "DeepSeek API Error Status: #{response.status}"
        Rails.logger.error "DeepSeek API Error Body: #{response.body}"
        nil
      end
    rescue => e
      Rails.logger.error "DeepSeek Service Exception: #{e.message}"
      nil
    end
  end
end
