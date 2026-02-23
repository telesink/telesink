Rails.application.routes.draw do
  root "sinks#index"

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :sinks

  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
