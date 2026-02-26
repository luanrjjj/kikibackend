Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :orgaos, defaults: { format: :json } do
    get :all, on: :collection
  end
  resources :bancas, defaults: { format: :json } do
    get :all, on: :collection
  end
  resources :assuntos, defaults: { format: :json } do
    get :all, on: :collection
  end
  resources :concursos, defaults: { format: :json } do
    get :all, on: :collection
  end

  resources :disciplinas, defaults: { format: :json } do
    get :all, on: :collection
  end

  resources :questaos, defaults: { format: :json } do
    member do
      patch :validate
    end
    get :all, on: :collection
    get :count, on: :collection
    get :filters_page_questaos, on: :collection
    get :stats, on: :collection
  end

  resources :provas, defaults: { format: :json } do
    get :all, on: :collection
    get :paginated_by_ano, on: :collection
    get :questaos, on: :collection
  end

  resources :area_de_formacao, only: [:index, :show]
  resources :area_de_atuacao, only: [:index, :show]

  post 'anki/generate', to: 'anki#generate'

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"


end
