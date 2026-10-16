# O usuário diz se a explicação por IA de uma questão ajudou (util: true) ou
# não (util: false). Uma por usuário, questão e provedor. Ver ExplicacaoIaService.
class ExplicacaoIaAvaliacao < ApplicationRecord
  self.table_name = 'explicacao_ia_avaliacoes'

  belongs_to :user
  belongs_to :questao

  validates :provedor, inclusion: { in: ->(_) { ExplicacaoIaService::PROVEDORES.keys } }
  validates :util, inclusion: { in: [true, false] }
end
