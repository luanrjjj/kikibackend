class TextoSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :texto, :imagem_texto
end
