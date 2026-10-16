# Cota diária de questões do acesso por IA.
#
# Cada questão entregue com dados completos (ferramentas questoes_do_caderno e
# questoes_para_anki do MCP, e /api/anki/questoes chamada com token pessoal)
# conta 1. O limite é de LIMITE_DIARIO questões por usuário por dia, no fuso de
# Brasília, e de MAX_POR_CHAMADA por chamada. Listar cadernos, estatísticas e
# ids de questões erradas não contam.
#
# O contador fica em mcp_usos_diarios (uma linha por usuário e dia). A reserva
# trava a linha, então duas chamadas simultâneas não passam do limite.
class McpCotaDiaria
  LIMITE_DIARIO = 1000
  MAX_POR_CHAMADA = 100
  FUSO = 'America/Sao_Paulo'.freeze

  class Esgotada < StandardError; end

  def self.hoje
    Time.current.in_time_zone(FUSO).to_date
  end

  def initialize(user, limite: LIMITE_DIARIO)
    @user = user
    @limite = limite
  end

  attr_reader :limite

  def usadas
    McpUsoDiario.where(user_id: @user.id, dia: self.class.hoje).pick(:questoes).to_i
  end

  def restantes
    [@limite - usadas, 0].max
  end

  # Reserva até `quantidade` questões da cota de hoje.
  # @return [Integer] quantas foram concedidas (pode ser menos que o pedido)
  # @raise [Esgotada] se a cota de hoje já acabou
  def reservar!(quantidade)
    quantidade = quantidade.to_i
    return 0 if quantidade <= 0

    concedidas = McpUsoDiario.transaction do
      uso = linha_de_hoje_travada
      livres = [@limite - uso.questoes, 0].max
      [quantidade, livres].min.tap do |n|
        uso.update_columns(questoes: uso.questoes + n, updated_at: Time.current) if n.positive?
      end
    end

    raise Esgotada, mensagem_esgotada if concedidas.zero?

    concedidas
  end

  # Devolve à cota questões reservadas que não foram entregues (ex.: ids que
  # não existem).
  def devolver!(quantidade)
    quantidade = quantidade.to_i
    return if quantidade <= 0

    McpUsoDiario.where(user_id: @user.id, dia: self.class.hoje)
                .update_all(['questoes = GREATEST(questoes - ?, 0), updated_at = ?', quantidade, Time.current])
  end

  def resumo
    usadas_hoje = usadas
    {
      limite_diario: @limite,
      usadas_hoje: usadas_hoje,
      restantes_hoje: [@limite - usadas_hoje, 0].max,
      max_por_chamada: MAX_POR_CHAMADA,
      renova_em: renova_em.iso8601
    }
  end

  def renova_em
    (self.class.hoje + 1).in_time_zone(FUSO).beginning_of_day
  end

  def mensagem_esgotada
    "Limite diário de #{@limite} questões pelo acesso por IA atingido. " \
      "A cota renova à meia-noite (horário de Brasília), em #{renova_em.iso8601}."
  end

  private

  def linha_de_hoje_travada
    dia = self.class.hoje
    # Cria a linha do dia se não existir (ON CONFLICT DO NOTHING) e trava.
    McpUsoDiario.insert_all([{ user_id: @user.id, dia: dia, questoes: 0 }], unique_by: %i[user_id dia])
    McpUsoDiario.lock.find_by!(user_id: @user.id, dia: dia)
  end
end
