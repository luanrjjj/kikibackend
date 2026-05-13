Sidekiq.configure_server do |config|
  if ENV['REDIS_HOST'].present?
    protocol = ENV['REDIS_SSL'] == 'true' ? 'rediss' : 'redis'
    auth = ENV['REDIS_PASSWORD'].present? ? "#{ENV['REDIS_USER']}:#{ENV['REDIS_PASSWORD']}@" : ""
    
    redis_config = {
      url: "#{protocol}://#{auth}#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
    }
    redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE } if protocol == 'rediss'
    
    config.redis = redis_config
  else
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1') }
  end
end

Sidekiq.configure_client do |config|
  if ENV['REDIS_HOST'].present?
    protocol = ENV['REDIS_SSL'] == 'true' ? 'rediss' : 'redis'
    auth = ENV['REDIS_PASSWORD'].present? ? "#{ENV['REDIS_USER']}:#{ENV['REDIS_PASSWORD']}@" : ""
    
    redis_config = {
      url: "#{protocol}://#{auth}#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}"
    }
    redis_config[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE } if protocol == 'rediss'
    
    config.redis = redis_config
  else
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1') }
  end
end
