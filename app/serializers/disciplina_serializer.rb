class DisciplinaSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :nome
end
