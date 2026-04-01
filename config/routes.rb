Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  root "sinks#index"
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post "sinks/:token/events", to: "events#create", as: :sink_events
    end
  end

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :sinks do
    resources :columns, only: %i[create show edit update destroy], controller: "sinks/columns" do
      resources :events, only: %i[index], controller: "sinks/columns/events"
      resources :views, only: %i[create], controller: "sinks/columns/views"
    end

    resource :column_order, only: %i[update], controller: "sinks/column_orders"
  end

  resources :events, only: %i[show]
end
