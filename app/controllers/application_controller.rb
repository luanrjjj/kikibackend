class ApplicationController < ActionController::API
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: -> { self.class == SessionsController }

  # Global Exception Handlers
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
  rescue_from ActiveRecord::RecordNotDestroyed, with: :handle_record_not_destroyed
  rescue_from ActiveRecord::InvalidForeignKey, with: :handle_foreign_key_violation
  rescue_from ActiveRecord::StatementInvalid, with: :handle_statement_invalid
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  def current_user
    @current_user
  end

  protected

  # Helper method for controllers to render model validation errors in a standard detailed format
  def render_validation_errors(record, error_title = "Erro de validação", status = :unprocessable_entity)
    Rails.logger.warn("[VALIDATION ERROR] #{record.class} (ID: #{record.id || 'new'}): #{record.errors.full_messages.to_sentence}")
    render json: {
      error: error_title,
      message: record.errors.full_messages.to_sentence,
      details: record.errors.messages
    }, status: status
  end

  private

  def handle_not_found(exception)
    Rails.logger.warn("[404 NOT FOUND] #{exception.class}: #{exception.message} | Path: #{request.path} | Params: #{filtered_params_inspect}")
    render json: {
      error: "Registro não encontrado",
      message: exception.message
    }, status: :not_found
  end

  def handle_record_invalid(exception)
    Rails.logger.warn("[422 RECORD INVALID] #{exception.class}: #{exception.message} | Record: #{exception.record&.class} | Errors: #{exception.record&.errors&.full_messages&.to_sentence}")
    render json: {
      error: "Erro de validação",
      message: exception.record.errors.full_messages.to_sentence,
      details: exception.record.errors.messages
    }, status: :unprocessable_entity
  end

  def handle_record_not_destroyed(exception)
    Rails.logger.warn("[422 NOT DESTROYED] #{exception.class}: #{exception.message} | Record: #{exception.record&.class}")
    render json: {
      error: "Não foi possível excluir o registro",
      message: exception.record&.errors&.full_messages&.to_sentence.presence || exception.message
    }, status: :unprocessable_entity
  end

  def handle_foreign_key_violation(exception)
    Rails.logger.error("[409 FOREIGN KEY VIOLATION] #{exception.class}: #{exception.message}")
    render json: {
      error: "Violação de integridade referencial",
      message: "Este registro não pode ser excluído ou modificado pois possui dependências vinculadas (ex: provas, questões ou resoluções associadas)."
    }, status: :conflict
  end

  def handle_statement_invalid(exception)
    Rails.logger.error("[500 DATABASE STATEMENT ERROR] #{exception.class}: #{exception.message}\n#{exception.backtrace&.first(10)&.join("\n")}")
    render json: {
      error: "Erro na consulta ao banco de dados",
      message: exception.message.split("\n").first
    }, status: :internal_server_error
  end

  def handle_parameter_missing(exception)
    Rails.logger.warn("[400 PARAMETER MISSING] #{exception.class}: #{exception.message}")
    render json: {
      error: "Parâmetro obrigatório ausente",
      message: exception.message
    }, status: :bad_request
  end

  def handle_standard_error(exception)
    log_msg = "[500 INTERNAL SERVER ERROR] #{exception.class}: #{exception.message}\n" \
              "Path: #{request.method} #{request.path}\n" \
              "Params: #{filtered_params_inspect}\n" \
              "Backtrace:\n#{exception.backtrace&.first(15)&.join("\n")}"
    Rails.logger.error(log_msg)

    render json: {
      error: "Erro interno do servidor",
      message: exception.message,
      exception: exception.class.to_s
    }, status: :internal_server_error
  end

  def filtered_params_inspect
    params.except(:password, :password_confirmation, :token).to_unsafe_h.inspect
  rescue StandardError
    params.to_s
  end

  def authenticate_admin!
    token = request.headers['Authorization']&.split(' ')&.last
    verification = User.verify_admin_token(token)

    if verification == :unauthorized
      render json: { error: 'Não autorizado', message: 'Token de administrador ausente ou inválido.' }, status: :unauthorized
    elsif verification == :forbidden
      render json: { error: 'Acesso negado', message: 'Você não possui permissões de administrador para esta ação.' }, status: :forbidden
    end
  end

  def authenticate_subscription
    unless current_user&.subscribed?
      render json: { error: 'Assinatura necessária', message: 'Esta funcionalidade requer uma assinatura ativa.' }, status: :method_not_allowed
    end
  end

  def verify_export_limit
    unless current_user&.can_export?
      render json: {
        error: 'Limite de exportação atingido',
        message: 'Usuários do plano gratuito podem exportar até 3 provas por mês. Assine para exportações ilimitadas.'
      }, status: :forbidden
    end
  end

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    if token
      session = Session.find_by(token: token)
      if session && session.expires_at > Time.current
        @current_user = session.user
      else
        render json: { error: 'Sessão inválida ou expirada', message: 'Sua sessão expirou. Por favor, faça login novamente.' }, status: :unauthorized
      end
    else
      render json: { error: 'Autenticação necessária', message: 'Token de autenticação não fornecido.' }, status: :unauthorized
    end
  end
end