Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_SECRET_ID']
  # provider :microsoft_graph, ENV['MICROSOFT_CLIENT_ID'], ENV['MICROSOFT_CLIENT_SECRET']
end

OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning = true