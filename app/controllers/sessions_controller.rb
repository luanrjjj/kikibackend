class SessionsController < ApplicationController
  def create
    Rails.logger.debug("FRONT_URL: #{ENV['SESSION_URL']}")
    puts "SESSION_URL: #{ENV['SESSION_URL']}"
    auth_hash = request.env['omniauth.auth']
    email = auth_hash.info.email

    # Encontra ou inicializa o usuário pelo email
    user = User.find_or_initialize_by(email: email)

    # Se for um novo usuário, preenche os dados e define uma senha aleatória
    if user.new_record?
      user.name = auth_hash.info.name
      user.provider = auth_hash.provider
      user.uid = auth_hash.uid
      user.password = SecureRandom.hex(16)
      user.save!
      StripeService.create_customer(user)
    end

    # Cria a sessão
    session = user.sessions.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      expires_at: 2.weeks.from_now
    )

    query_params = {
      token: session.token,
      user: user.as_json(except: :password_digest).to_json
    }

    redirect_to "#{ENV['SESSION_BASE_NEW_URL']}/login?#{query_params.to_query}", allow_other_host: true
  end

  def authenticate
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session = user.sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        expires_at: 2.weeks.from_now
      )

      render json: {
        token: session.token,
        user: user.as_json(except: :password_digest)
      }
    else
      render json: { error: "Email ou senha inválidos" }, status: :unauthorized
    end
  end

  def register
    user = User.new(register_params)

    if user.save
      session = user.sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        expires_at: 2.weeks.from_now
      )

      render json: {
        token: session.token,
        user: user.as_json(except: :password_digest)
      }, status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def failure
    render json: { error: "Falha na autenticação", message: params[:message] }, status: :unauthorized
  end

  private

  def register_params
    params.permit(:email, :password, :password_confirmation, :name)
  end
end
