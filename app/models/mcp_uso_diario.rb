# Contador diário de questões entregues pelo acesso por IA. Ver McpCotaDiaria.
class McpUsoDiario < ApplicationRecord
  self.table_name = 'mcp_usos_diarios'

  belongs_to :user
end
