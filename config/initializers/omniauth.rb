Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_SECRET_ID']
  # provider :microsoft_graph, ENV['MICROSOFT_CLIENT_ID'], ENV['MICROSOFT_CLIENT_SECRET']
end

OmniAuth.config.allowed_request_methods = %i[get post]
OmniAuth.config.silence_get_warning = true

#if Rails.env.production?
 # OmniAuth.config.full_host = ->(env) {
  #  scheme = env['rack.url_scheme']
   # host = env['HTTP_HOST']

    # Se houver X-Forwarded-Host (comum em proxies), usamos ele
    #if env['HTTP_X_FORWARDED_HOST']
     # host = env['HTTP_X_FORWARDED_HOST'].split(',').first.strip
      #scheme = env['HTTP_X_FORWARDED_PROTO'] || scheme
    #end

    # Como a API está sendo servida sob o prefixo /api no Nginx, forçamos o prefixo
    #"#{scheme}://#{host}/api"
  #}
#end