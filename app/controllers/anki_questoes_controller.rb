# Dados de questões para o usuário criar flashcards (Anki) com a própria IA.
# Só para assinantes.
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
# Máximo de 100 ids por requisição.
class AnkiQuestoesController < ApplicationController
  include AutenticacaoPorApiToken

  skip_before_action :authenticate_user!
  before_action :authenticate_api_token_ou_sessao!
  before_action :exigir_plano_pago!

  # GET /api/anki/questoes/:id
  def show
    resultado = servico.buscar([params[:id]])
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

    render json: servico.buscar(ids)
  rescue AnkiQuestoesService::LimiteExcedido => e
    render json: { error: 'Muitos ids', message: e.message }, status: :unprocessable_entity
  end

  private

  def servico
    AnkiQuestoesService.new(
      current_user,
      incluir_comentarios: ActiveModel::Type::Boolean.new.cast(params[:incluir_comentarios]),
      limite_comentarios: params[:limite_comentarios].presence || 3
    )
  end
end
