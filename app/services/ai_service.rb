class AiService
  def self.generate_cards(question_text, context_text, correct_answer)
    provider = ConfigGlobalApolo.get('ai_api_name', 'gemini').downcase

    case provider
    when 'deepseek'
      DeepSeekService.generate_cards(question_text, context_text, correct_answer)
    else
      GeminiService.generate_cards(question_text, context_text, correct_answer)
    end
  end
end
