Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy] do
        put :password, to: "sessions#update_password"
      end
      get "health", to: "health#show"
    end
  end
end
