# Planos de assinatura e o que cada um libera.
#
# As permissões ficam em `variaveis`, uma lista de strings editável no painel
# admin, no formato "chave:valor" ("create_notebook_basic:true",
# "limit_resolutions_free:100") ou só "chave" (equivale a true).
#
# Recursos (chave => o que libera):
#   limit_resolutions_free                  limite de resoluções de questões (sem a chave: ilimitado)
#   anki_export_by_week_free                exportações para o Anki por semana (sem a chave: ilimitado)
#   create_notebook_basic                   criar cadernos
#   guide_access                            acessar os guias
#   show_stats_table_by_assunto_basic       estatísticas por assunto na página de estatísticas
#   edital_verticalized_advanced            exportar o edital verticalizado
#   excel_stats_export_advanced             exportar estatísticas para Excel
#   ankis_personalized_advanced             Ankis personalizados
#   ia_concept_question_extraction_advanced flashcards de conceitos com IA
#   mcp_access                              acesso por IA com token pessoal (MCP e questões para Anki)
class Plano < ApplicationRecord
  # Nomes aceitos para cada nível (comparados sem diferenciar maiúsculas).
  NIVEIS = {
    free: %w[free gratis grátis gratuito],
    basic: %w[basic basico básico],
    advanced: %w[advanced avancado avançado pro]
  }.freeze

  RECURSOS_BOOLEANOS = %w[
    create_notebook_basic
    guide_access
    show_stats_table_by_assunto_basic
    edital_verticalized_advanced
    excel_stats_export_advanced
    ankis_personalized_advanced
    ia_concept_question_extraction_advanced
    mcp_access
  ].freeze

  RECURSOS_COM_LIMITE = %w[limit_resolutions_free anki_export_by_week_free].freeze

  # Valores de cada nível. É o que a migração de dados grava no banco e o que
  # vale enquanto o plano não existir na tabela. Com o plano no banco, valem as
  # variáveis dele (editáveis no admin).
  PADROES = {
    free: {
      'limit_resolutions_free' => 100,
      'anki_export_by_week_free' => 1,
      'create_notebook_basic' => true,
      'show_stats_table_by_assunto_basic' => false,
      'excel_stats_export_advanced' => false,
      'guide_access' => false,
      'ankis_personalized_advanced' => false,
      'mcp_access' => false
    },
    basic: {
      'create_notebook_basic' => true,
      'show_stats_table_by_assunto_basic' => true,
      'edital_verticalized_advanced' => true,
      'guide_access' => true,
      'mcp_access' => false,
      'ia_concept_question_extraction_advanced' => false
    },
    advanced: {
      'excel_stats_export_advanced' => true,
      'ankis_personalized_advanced' => true,
      'ia_concept_question_extraction_advanced' => true,
      'edital_verticalized_advanced' => true,
      'show_stats_table_by_assunto_basic' => true,
      'create_notebook_basic' => true,
      'mcp_access' => true,
      'guide_access' => true
    }
  }.freeze

  # Plano mínimo que libera cada recurso, para o modal de assinatura dizer
  # qual plano assinar.
  NIVEL_MINIMO = {
    'limit_resolutions_free' => :basic,
    'anki_export_by_week_free' => :basic,
    'create_notebook_basic' => :basic,
    'guide_access' => :basic,
    'show_stats_table_by_assunto_basic' => :basic,
    'edital_verticalized_advanced' => :basic,
    'excel_stats_export_advanced' => :advanced,
    'ankis_personalized_advanced' => :advanced,
    'ia_concept_question_extraction_advanced' => :advanced,
    'mcp_access' => :advanced
  }.freeze

  MENSAGENS = {
    'limit_resolutions_free' => 'Você atingiu o limite de questões do plano gratuito.',
    'anki_export_by_week_free' => 'Você atingiu o limite de exportações para o Anki desta semana.',
    'create_notebook_basic' => 'Criar cadernos personalizados não está disponível no seu plano.',
    'guide_access' => 'Os guias de estudo são exclusivos para assinantes.',
    'show_stats_table_by_assunto_basic' => 'As estatísticas por assunto não estão disponíveis no seu plano.',
    'edital_verticalized_advanced' => 'Exportar o edital verticalizado não está disponível no seu plano.',
    'excel_stats_export_advanced' => 'Exportar estatísticas para o Excel é exclusivo do plano Pro.',
    'ankis_personalized_advanced' => 'Ankis personalizados são exclusivos do plano Pro.',
    'ia_concept_question_extraction_advanced' => 'Flashcards de conceitos com IA são exclusivos do plano Pro.',
    'mcp_access' => 'O acesso por IA (MCP e questões para Anki) é exclusivo do plano Pro.'
  }.freeze

  def self.do_nivel(nivel)
    where('LOWER(nome_do_plano) IN (?)', NIVEIS.fetch(nivel)).order(:id).first
  end

  # Nível de uma assinatura a partir de User#plan ("BASIC", "PRO", "MONTHLY"...).
  # Assinaturas antigas, de antes dos planos Básico e Pro, ficam no nível mais alto,
  # como já acontecia.
  def self.nivel_da_assinatura(plan)
    plan.to_s.downcase.match?(/basic|b[aá]sico/) ? :basic : :advanced
  end

  # Variáveis efetivas de um nível: as do banco, ou PADROES se o plano não existir.
  def self.variaveis_do_nivel(nivel)
    registro = do_nivel(nivel)
    registro ? registro.variaveis_hash : PADROES.fetch(nivel).dup
  end

  # Converte a lista de strings em hash: "true"/"false" (qualquer caixa) viram
  # booleanos e números viram inteiros.
  def self.interpretar(lista)
    Array(lista).each_with_object({}) do |item, hash|
      chave, valor = item.to_s.split(':', 2).map(&:strip)
      next if chave.blank?

      hash[chave] =
        if valor.nil? then true
        elsif valor.casecmp?('true') then true
        elsif valor.casecmp?('false') then false
        elsif valor.match?(/\A-?\d+\z/) then valor.to_i
        else valor
        end
    end
  end

  # Lista de strings a partir de um hash, no formato salvo em `variaveis`.
  def self.serializar(hash)
    hash.map { |chave, valor| "#{chave}:#{valor}" }
  end

  def variaveis_hash
    self.class.interpretar(variaveis)
  end
end
