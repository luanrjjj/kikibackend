class QuestaoSerializer
  include FastJsonapi::ObjectSerializer
  set_id { |object| object[:id] }
  attributes :enunciado, :ano, :discursiva, :alternativas, :correta, :topico_id

  attribute :topico do |object|
    if object.topico
      {
        id: object.topico.id,
        nome: object.topico.nome
      }
    end
  end

  attribute :id do |object|
    object[:id]
  end

  attribute :comentarios_count do |object|
    if object.respond_to?(:comentarios_count_val)
      object.comentarios_count_val
    elsif object.association(:comentarios).loaded?
      object.comentarios.size
    else
      object.comentarios.count
    end
  end

  attribute :assunto do |object|
    if object.assunto
      {
        id: object.assunto.id,
        nome: object.assunto.nome
      }
    end
  end

  attribute :disciplina do |object|
    if object.disciplina
      {
        id: object.disciplina.id,
        nome: object.disciplina.nome
      }
    end
  end

  attribute :texto do |object|
    if object.texto
      {
        id: object.texto.id,
        texto: object.texto.texto,
        imagem_texto: object.texto.imagem_texto
      }
    end
  end

  attribute :concurso do |object, params|
    concurso = object.concurso || (params && params[:prova]&.concurso) || (object.association(:provas).loaded? ? object.provas.first&.concurso : object.provas.first&.concurso)
    if concurso
      {
        id: concurso.id,
        nome: concurso.nome
      }
    end
  end

  attribute :banca do |object, params|
    banca = object.concurso&.banca || (params && params[:prova]&.banca) || (object.association(:provas).loaded? ? object.provas.first&.banca : object.provas.first&.banca)
    if banca
      {
        id: banca.id,
        nome: banca.nome,
        sigla: banca.sigla,
        logo: banca.logo
      }
    end
  end

  attribute :orgao do |object, params|
    orgao = object.concurso&.orgao || (params && params[:prova]&.orgao) || (object.association(:provas).loaded? ? object.provas.first&.orgao : object.provas.first&.orgao)
    if orgao
      {
        id: orgao.id,
        nome: orgao.nome,
        sigla: orgao.sigla,
        logo_url: orgao.logo_url
      }
    end
  end

  attribute :prova do |object, params|
    prova = (params && params[:prova]) || (object.association(:provas).loaded? ? object.provas.first : object.provas.first)
    if prova
      {
        id: prova.id,
        nome: prova.nome
      }
    end
  end

  attribute :resolucao do |object, params|
    if params && params[:resolucoes]
      res = params[:resolucoes][object[:id]]
      if res
        {
          id: res[:id],
          resposta: res.resposta,
          correta: res.correta,
          created_at: res.created_at
        }
      end
    end
  end
end
