if Rails.env.development?
  Rails.application.configure do
    config.web_console.permissions = '0.0.0.0/0'
  end
end