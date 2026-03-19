class ProvaQuestaoSerializer
  include FastJsonapi::ObjectSerializer
  attributes :id, :prova_id, :questao_id, :numero_questao

  attribute :questao do |object|
    QuestaoSerializer.new(object.questao).serializable_hash.dig(:data, :attributes)
  end
end
