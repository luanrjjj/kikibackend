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

  attribute :concurso do |object|
    if object.concurso
      {
        id: object.concurso.id,
        nome: object.concurso.nome
      }
    end
  end

  attribute :orgao do |object|
    # Get orgao from concurso or prova
    orgao = object.concurso&.orgao || object.provas.first&.orgao
    if orgao
      {
        id: orgao.id,
        nome: orgao.nome,
        logo_url: orgao.logo_url
      }
    end
  end

  attribute :prova do |object|
    prova = object.provas.first
    if prova
      {
        id: prova.id,
        nome: prova.nome
      }
    end
  end
end

