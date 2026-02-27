Rails.application.routes.draw do
  root "sinks#index"
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :sinks do
    resources :columns, only: %i[create], controller: "sinks/columns"
  end
end
