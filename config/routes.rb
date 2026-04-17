Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
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
  resources :concursos, defaults: { format: :json } do
    get :all, on: :collection
    get :public_index, on: :collection
    get :stats, on: :collection
  end

  resources :disciplinas, defaults: { format: :json } do
    get :all, on: :collection
    get :filters, on: :collection
  end

  resources :questaos, defaults: { format: :json } do
    member do
      patch :validate
    end
    get :all, on: :collection
    get :count, on: :collection
    get :ids, on: :collection
    get :filters_page_questaos, on: :collection
    get :stats, on: :collection
  end

  resources :provas, defaults: { format: :json } do
    get :all, on: :collection
    get :paginated_by_ano, on: :collection
    get :questaos, on: :collection
    get :stats, on: :collection
    get :years, on: :collection
  end

  resources :prova_questaos, only: [:index], defaults: { format: :json }

  resources :area_de_formacao, only: [:index, :show]
  resources :area_de_atuacao, only: [:index, :show]
  resources :planos, only: [:index], defaults: { format: :json }
  resources :cadernos, defaults: { format: :json } do
    get :questaos, on: :member
  end
  resources :resolucoes, only: [:create], defaults: { format: :json }

  post 'anki/generate', to: 'anki#generate'

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'
  post '/auth/login', to: 'sessions#authenticate'
  post '/auth/register', to: 'sessions#register'
  post '/auth/forgot_password', to: 'sessions#forgot_password'
  post '/auth/reset_password', to: 'sessions#reset_password'

  resources :payments, only: [:index, :create], defaults: { format: :json } do
    post :subscribe, on: :collection
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"


end
