# Dados de questões para o usuário criar flashcards (Anki) com a própria IA.
# Exige mcp_access no plano (Pro).
#
# Autenticação: token pessoal (apl_...) gerado em Configurações > Acesso por IA,
# ou o token de sessão do site.
#
#   GET  /api/anki/questoes/123
#   GET  /api/anki/questoes?ids=123,456,789     (ou ids[]=123&ids[]=456, ou id=123)
#   POST /api/anki/questoes   { "ids": [123, 456] }   (para listas longas)
#
# Parâmetros opcionais:
#   incluir_comentarios=true   traz os comentários mais votados
#   limite_comentarios=3       quantos comentários por questão (1 a 5)
#
# Máximo de 100 ids por requisição. Com token pessoal, cada questão entregue
# conta na cota diária do acesso por IA (McpCotaDiaria, 1000 por dia), a mesma
# do MCP. Com a sessão do site não há cota.
class AnkiQuestoesController < ApplicationController
  include AutenticacaoPorApiToken

  skip_before_action :authenticate_user!
  before_action :authenticate_api_token_ou_sessao!
  before_action :exigir_acesso_mcp!

  # GET /api/anki/questoes/:id
  def show
    resultado = buscar_com_cota(AnkiQuestoesService.normalizar_ids(params[:id]))
    return if performed?

    questao = resultado[:questoes].first

    if questao
      render json: questao
    else
      render json: { error: 'Questão não encontrada', message: "Não existe questão com id #{params[:id]}." }, status: :not_found
    end
  end

  # GET  /api/anki/questoes?ids=1,2,3
  # POST /api/anki/questoes { ids: [1, 2, 3] }
  def index
    ids = AnkiQuestoesService.normalizar_ids(params[:ids].presence || params[:id])

    if ids.empty?
      return render json: {
        error: 'Parâmetro obrigatório ausente',
        message: 'Informe um id (id=123) ou vários (ids=123,456 ou ids[]=123&ids[]=456).'
      }, status: :bad_request
    end

    if ids.length > AnkiQuestoesService::MAX_IDS
      return render json: {
        error: 'Muitos ids',
        message: "Envie no máximo #{AnkiQuestoesService::MAX_IDS} ids por requisição (recebidos: #{ids.length})."
      }, status: :unprocessable_entity
    end

    resultado = buscar_com_cota(ids)
    render json: resultado unless performed?
  rescue AnkiQuestoesService::LimiteExcedido => e
    render json: { error: 'Muitos ids', message: e.message }, status: :unprocessable_entity
  end

  private

  # Sem token pessoal (sessão do site), não aplica a cota.
  def buscar_com_cota(ids)
    return servico.buscar(ids) unless current_api_token

    cota = McpCotaDiaria.new(current_user)
    concedidas = cota.reservar!(ids.length)
    resultado = servico.buscar(ids.first(concedidas))
    cota.devolver!(resultado[:nao_encontradas].length)
    response.set_header('X-Cota-Restante', cota.restantes.to_s)
    resultado.merge(nao_entregues_pela_cota: ids.drop(concedidas), cota: cota.resumo)
  rescue McpCotaDiaria::Esgotada => e
    response.set_header('Retry-After', [(cota.renova_em - Time.current).ceil, 1].max.to_s)
    render json: { error: 'Cota diária atingida', message: e.message, cota: cota.resumo }, status: :too_many_requests
    nil
  end

  def servico
    AnkiQuestoesService.new(
      current_user,
      incluir_comentarios: ActiveModel::Type::Boolean.new.cast(params[:incluir_comentarios]),
      limite_comentarios: params[:limite_comentarios].presence || 3
    )
  end
end
