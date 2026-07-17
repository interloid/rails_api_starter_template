Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Dependency-aware health checks (detailed diagnostics + readiness probe).
  get "/health",       to: "health#show"
  get "/health/ready", to: "health#ready"

  namespace :api do
    namespace :v1 do
      get "status", to: "status#show"
      resources :users, only: %i[index show update destroy]

      post "auth/register", to: "auth#register"
      post "auth/login",    to: "auth#login"
      post "auth/refresh",  to: "auth#refresh"
      post "auth/logout",   to: "auth#logout"
      get  "auth/me",       to: "auth#me"

      post "account/confirm_email",       to: "account#confirm_email"
      post "account/resend_confirmation", to: "account#resend_confirmation"
      post "account/forgot_password",     to: "account#forgot_password"
      post "account/reset_password",      to: "account#reset_password"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"

  # Interactive API docs — DEVELOPMENT ONLY. Must be mounted BEFORE the catch-all
  # below, or /api-docs would be swallowed by the "*unmatched" route.
  if Rails.env.development?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
    # Solid Queue dashboard (jobs, workers, failed jobs). Production gating: Section 14.
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Unknown endpoints return the JSON envelope, not Rails' HTML 404. Keep LAST.
  match "*unmatched", to: "application#route_not_found", via: :all
end
