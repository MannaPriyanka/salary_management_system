Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy] do
        put :password, to: "sessions#update_password"
      end

      resources :employees, only: %i[index show create update] do
        member do
          post :archive
          post :unarchive
        end
        resources :salary_revisions, only: %i[index create]
        resources :audit_entries, only: :index
      end

      get "departments", to: "reference_data#departments"
      get "designations", to: "reference_data#designations"
      get "countries", to: "reference_data#countries"
      get "currencies", to: "reference_data#currencies"

      get "statistics/summary", to: "statistics#summary"
      get "statistics/breakdown", to: "statistics#breakdown"

      get "health", to: "health#show"
    end
  end

  match "api/*unmatched", to: "errors#api_not_found", via: :all
  root to: "spa#index"
  get "*path", to: "spa#index", constraints: ->(request) { !request.path.start_with?("/api/") }
end
