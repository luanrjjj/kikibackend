class Caderno < ApplicationRecord
  belongs_to :user
  belongs_to :prova, optional: true
  belongs_to :concurso, optional: true
  belongs_to :pasta_caderno
  belongs_to :filtro, optional: true

  has_many :resolucoes, class_name: 'Resolucao', dependent: :destroy

  before_validation :set_default_pasta, on: :create
  before_validation :ensure_unique_nome, on: :create
  before_save :unique_questoes_ids
  before_save :touch_questoes_atualizadas_em
  before_create :populate_questoes_from_prova
  before_create :create_associated_filtro

  validates :nome, presence: true, uniqueness: { scope: :user_id }
  validates :pasta_caderno_id, presence: true
  validate :validate_max_questoes

  FILTER_GROUP_COLUMNS = %w[filtros filtros_2 filtros_3].freeze

  # Re-runs the notebook's filter groups (or its prova) against the current
  # question bank and appends the questions it doesn't have yet.
  # Questions already in the notebook are never removed or reordered.
  #
  # @param max_limit [Integer] maximum number of questions allowed in the notebook
  # @return [Hash] summary for the API response
  def verificar_atualizacoes!(max_limit:)
    atuais = Array(questoes_ids).map(&:to_i)
    atuais_set = atuais.to_set
    grupos = []
    candidatos = []

    FILTER_GROUP_COLUMNS.each_with_index do |col, idx|
      filtro = self[col]
      next if filtro.blank?

      filtro = filtro.to_h.with_indifferent_access
      next unless QuestaoFilterService.any_criteria?(filtro_para_busca(filtro))

      ids = QuestaoFilterService.apply(Questao.all, filtro_para_busca(filtro)).pluck(:id)
      grupos << { grupo: idx + 1, coluna: col, total: ids.size, novas: ids.count { |id| !atuais_set.include?(id) } }
      candidatos.concat(ids)
    end

    if prova_id.present? && prova
      ids = prova.prova_questaos.order(numero_questao: :asc).pluck(:questao_id).compact
      grupos << { grupo: 'prova', total: ids.size, novas: ids.count { |id| !atuais_set.include?(id) } }
      candidatos.concat(ids)
    end

    novas = candidatos.uniq.reject { |id| atuais_set.include?(id) }
    vagas = [max_limit - atuais.size, 0].max
    adicionadas = novas.first(vagas)

    # Keep each group's stored count in sync with what the filter returns today
    grupos.each do |g|
      next unless g[:coluna]
      self[g[:coluna]] = self[g[:coluna]].to_h.merge('questoes_count' => g[:total])
    end

    self.questoes_ids = atuais + adicionadas if adicionadas.any?
    self.questoes_verificadas_em = Time.current
    save!

    {
      adicionadas: adicionadas.size,
      encontradas: novas.size,
      nao_adicionadas_por_limite: novas.size - adicionadas.size,
      max_caderno_questoes: max_limit,
      total_questoes: Array(questoes_ids).size,
      grupos: grupos.map { |g| g.except(:coluna) },
      sem_filtros: grupos.empty?,
      questoes_atualizadas_em: questoes_atualizadas_em,
      questoes_verificadas_em: questoes_verificadas_em
    }
  end

  private

  # Maps a stored filter group to QuestaoFilterService keys.
  # Older notebooks don't store the anuladas/desatualizadas toggles; the filter
  # screen defaults both to true, so that's the fallback.
  def filtro_para_busca(filtro)
    {
      bancas: filtro[:bancas],
      orgaos: filtro[:orgaos],
      ano: filtro[:ano],
      escolaridade: filtro[:escolaridades].presence || filtro[:escolaridade],
      disciplinas: filtro[:disciplinas].presence || Array(filtro[:id_da_disciplina].presence),
      assuntos: filtro[:assuntos],
      topicos: filtro[:topicos],
      remover_anuladas: filtro.key?(:remover_anuladas) ? filtro[:remover_anuladas] : true,
      remover_desatualizadas: filtro.key?(:remover_desatualizadas) ? filtro[:remover_desatualizadas] : true
    }
  end

  def touch_questoes_atualizadas_em
    if new_record? || will_save_change_to_questoes_ids?
      self.questoes_atualizadas_em = Time.current
    end
  end

  def validate_max_questoes
    return if questoes_ids.blank?
    max_limit = user&.variaveis&.dig('max_caderno_questoes').to_i
    max_limit = 10_000 if max_limit <= 0
    if Array(questoes_ids).map(&:to_i).uniq.length > max_limit
      errors.add(:questoes_ids, "Excedeu a quantidade máxima de #{max_limit}")
    end
  end

  def unique_questoes_ids
    return if questoes_ids.blank?
    
    # Ensure all elements are integers and unique
    self.questoes_ids = Array(questoes_ids).map { |id| id.to_i }.uniq
  end

  def create_associated_filtro
    return if filtros.blank?
    
    # Find the main discipline and subject IDs from the current questions if not explicitly provided
    # The 'filtros' column currently comes from the frontend params.
    # We want to ensure it follows: {nome_da_disciplina, id_da_disciplina, assuntos:[ids]}
    
    # If the 'filtros' is already a hash (JSON), we use it. 
    # Based on user request, the JSON format should be specific.
    
    # Create the filter record
    novo_filtro = Filtro.create!(
      user_id: user_id,
      nome_do_filtro: nome,
      filtro: filtros
    )

    # Associate the new filter's ID to this caderno
    self.filtro_id = novo_filtro.id
  end

  def ensure_unique_nome
    return if nome.blank? || !user_id.present?

    # Strip existing " (n)" suffix to get the base name
    base_nome = nome.gsub(/\s\(\d+\)$/, "")
    new_nome = nome
    counter = 1
    
    while user.cadernos.where.not(id: id).exists?(nome: new_nome)
      new_nome = "#{base_nome} (#{counter})"
      counter += 1
    end
    self.nome = new_nome
  end

  def set_default_pasta
    return if pasta_caderno_id.present?
    
    default_pasta = user.pasta_cadernos.find_or_create_by!(nome: 'Meus Cadernos')
    self.pasta_caderno_id = default_pasta.id
  end

  def populate_questoes_from_prova
    if prova_id.present? && questoes_ids.blank?
      self.questoes_ids = prova.prova_questaos.order(numero_questao: :asc).pluck(:questao_id).compact
    end
  end
end
