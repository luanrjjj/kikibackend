class QuestaoSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :enunciado, :ano, :discursiva, :alternativas, :correta, :numero_questao

  belongs_to :assunto
  belongs_to :disciplina
  belongs_to :texto
end
