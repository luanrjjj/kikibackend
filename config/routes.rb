require 'sidekiq/web'

# Inject Rails session middleware into Sidekiq Web UI
Sidekiq::Web.use ActionDispatch::Cookies
Sidekiq::Web.use ActionDispatch::Session::CookieStore, Rails.application.config.session_options

# Disable CSP for Sidekiq Web UI to ensure JS/CSS from the engine load correctly
Sidekiq::Web.use Rack::ContentSecurityPolicy, default_src: "'self' 'unsafe-inline' 'unsafe-eval'" if defined?(Rack::ContentSecurityPolicy)

Rails.application.routes.draw do
  scope '/api' do
    # Sidekiq Web UI with Basic Auth
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_USERNAME", "admin"))) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV.fetch("SIDEKIQ_PASSWORD", "password")))
    end
    mount Sidekiq::Web => '/sidekiq'

    resources :orgaos, defaults: { format: :json } do
      get :all, on: :collection
      get :filters, on: :collection
    end
    resources :bancas, defaults: { format: :json } do
      get :all, on: :collection
      get :filters, on: :collection
      get :questoes_count, on: :collection
    end
    resources :assuntos, defaults: { format: :json } do
      get :all, on: :collection
      get :filters, on: :collection
    end
    resources :topicos, defaults: { format: :json } do
      get :all, on: :collection
    end
    resources :concursos, defaults: { format: :json } do
      get :all, on: :collection
      get :public_index, on: :collection
      get :stats, on: :collection
      delete :destroy_by_name, on: :collection
      post :create_s3_folder, on: :member
      post :upload_edital, on: :member
    end

    resources :disciplinas, defaults: { format: :json } do
      get :all, on: :collection
      get :filters, on: :collection
    end

    resources :questaos, defaults: { format: :json } do
      member do
        patch :validate
      end
      resources :reports, only: [:create], defaults: { format: :json }
      get :all, on: :collection
      get :count, on: :collection
      get :ids, on: :collection
      get :filters_page_questaos, on: :collection
      get :stats, on: :collection
    end

    resources :provas, defaults: { format: :json } do
      get :all, on: :collection
      get :paginated_by_ano, on: :collection
      get :popular, on: :collection
      get :questaos, on: :member
      get :stats, on: :collection
      get :years, on: :collection
    end

    resources :prova_questaos, only: [:index], defaults: { format: :json }

    resources :area_de_formacao, only: [:index, :show]
    resources :area_de_atuacao, only: [:index, :show]
    resources :planos, defaults: { format: :json } do
      get :all, to: 'planos#index', on: :collection
    end
    
    resources :pasta_cadernos, defaults: { format: :json }
    resources :reports, only: [:index, :show, :update, :destroy], defaults: { format: :json }
    resources :filtros, only: [:index, :create], defaults: { format: :json } do
      get :all, on: :collection
    end
    resources :guias, defaults: { format: :json } do
      get :public_index, on: :collection
    end
    resources :cargo_guias, defaults: { format: :json }
    resources :config_global_apolos, defaults: { format: :json }
    resources :edital_vert, defaults: { format: :json }
    
    resources :cadernos, defaults: { format: :json } do
      get :questaos, on: :member
    end

    resources :resolucoes, only: [:index, :create], defaults: { format: :json } do
      get :stats, on: :collection
      get :global_stats, on: :collection
      get :discipline_stats, on: :collection
      get :subject_stats, on: :collection
      get :hierarchical_stats, on: :collection
      get :export_excel_stats, on: :collection
      get :notebook_stats, on: :collection
      get :question_stats, on: :collection
    end

    resources :comentarios, only: [:index, :create], defaults: { format: :json } do
      member do
        patch :upvote
        patch :downvote
      end
    end

    post 'anki/generate', to: 'anki#generate'
    post 'anki/generate_ai', to: 'anki#generate_ai'
    post 'anki/ai_generate_json', to: 'anki#ai_generate_json'

    get '/auth/:provider/callback', to: 'sessions#create'
    get '/auth/failure', to: 'sessions#failure'
    post '/auth/login', to: 'sessions#authenticate'
    post '/auth/register', to: 'sessions#register'
    post '/auth/forgot_password', to: 'sessions#forgot_password'
    post '/auth/reset_password', to: 'sessions#reset_password'

    resources :payments, only: [:index, :create], defaults: { format: :json } do
      post :subscribe, on: :collection
    end

    resources :users, only: [:index, :show, :update], defaults: { format: :json }

    get 'up' => 'rails/health#show', as: :rails_health_check

    post 'admin/refresh_stats', to: 'admin#refresh_stats'
    get 'admin/user_stats', to: 'admin#user_stats'
    get 'admin/configs', to: 'admin#get_configs'
    post 'admin/set_config', to: 'admin#set_config'
  end
end
