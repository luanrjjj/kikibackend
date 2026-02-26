class AssuntoSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :nome
end
