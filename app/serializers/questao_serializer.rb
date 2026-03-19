class QuestaoSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :enunciado, :ano, :discursiva, :alternativas, :correta

  attribute :assunto do |object|
    AssuntoSerializer.new(object.assunto).serializable_hash.dig(:data, :attributes) if object.assunto
  end

  attribute :disciplina do |object|
    DisciplinaSerializer.new(object.disciplina).serializable_hash.dig(:data, :attributes) if object.disciplina
  end

  attribute :texto do |object|
    TextoSerializer.new(object.texto).serializable_hash.dig(:data, :attributes) if object.texto
  end
end

