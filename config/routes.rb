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
      end

      get "departments", to: "reference_data#departments"
      get "designations", to: "reference_data#designations"
      get "countries", to: "reference_data#countries"
      get "currencies", to: "reference_data#currencies"

      get "health", to: "health#show"
    end
  end
end
