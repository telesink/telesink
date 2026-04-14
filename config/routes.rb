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

  resource :settings, only: %i[show] do
    resource :nickname, only: %i[edit update], controller: "settings/nicknames"
    resource :email, only: %i[edit update], controller: "settings/emails"
    resource :password, only: %i[edit update], controller: "settings/passwords"

    resource :invitations, only: %i[show], controller: "settings/invitations"

    resources :members, only: %i[index show], controller: "settings/members" do
      resource :role, only: %i[edit update], controller: "settings/members/roles"
      resources :sinks, only: %i[index], controller: "settings/members/sinks" do
        collection do
          patch :update
        end
      end
    end
  end

  resource :account do
    scope module: "accounts" do
      resource :join_code, only: %i[create]
    end
  end

  get "join/:join_code", to: "joins#new", as: :join
  post "join/:join_code", to: "joins#create"
end
