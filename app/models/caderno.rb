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
  before_create :populate_questoes_from_prova
  before_create :create_associated_filtro

  validates :nome, presence: true, uniqueness: { scope: :user_id }
  validates :pasta_caderno_id, presence: true

  private

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
