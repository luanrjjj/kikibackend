require 'did_you_mean'

# Compara nomes de assuntos/tópicos para achar o "equivalente" de um item com
# poucas questões entre itens maiores (kikiapps#12). Não acessa o banco, para
# poder ser testado isoladamente.
#
#   EquivalenciaClassificacao.melhor("Crase: regras gerais", [[10, "Crase"], [11, "Regência"]])
#   # => { id: 10, nome: "Crase", score: 0.93 }
module EquivalenciaClassificacao
  STOPWORDS = %w[
    a o as os e de da do das dos em no na nos nas um uma uns umas para por com sem
    ao aos à às sobre entre ou que se
  ].freeze

  module_function

  # minúsculas, sem acento, sem pontuação, sem stopwords
  def normalizar(nome)
    texto = ActiveSupport::Inflector.transliterate(nome.to_s).downcase
    texto = texto.gsub(/[^a-z0-9\s]/, ' ')
    texto.split.reject { |t| STOPWORDS.include?(t) }.join(' ')
  end

  def tokens(nome)
    normalizar(nome).split.to_set
  end

  # 0..1 — o maior entre: Jaro-Winkler, razão de Levenshtein, Jaccard dos
  # tokens e "contido em" (todos os tokens do nome menor estão no maior).
  def similaridade(a, b)
    na = normalizar(a)
    nb = normalizar(b)
    return 0.0 if na.empty? || nb.empty?
    return 1.0 if na == nb

    jw = DidYouMean::JaroWinkler.distance(na, nb)
    lev = 1.0 - DidYouMean::Levenshtein.distance(na, nb).to_f / [na.length, nb.length].max

    ta = na.split.to_set
    tb = nb.split.to_set
    inter = (ta & tb).size
    jaccard = inter.to_f / (ta | tb).size

    menor = ta.size <= tb.size ? ta : tb
    # "Crase" ⊂ "Crase regras gerais": forte, mas só quando o menor é
    # informativo (2+ tokens, ou 1 token com 5+ letras) para não casar
    # "Lei" com "Lei de Licitações".
    informativo = menor.size >= 2 || menor.first.to_s.length >= 5
    contido = informativo && inter == menor.size ? 0.9 : 0.0

    [jw, lev, jaccard, contido].max.round(3)
  end

  # candidatos: [[id, nome], ...]. Devolve o mais parecido (ou nil).
  def melhor(nome, candidatos)
    melhor = nil
    candidatos.each do |id, outro_nome|
      score = similaridade(nome, outro_nome)
      melhor = { id: id, nome: outro_nome, score: score } if melhor.nil? || score > melhor[:score]
    end
    melhor
  end
end
