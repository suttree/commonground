Rails.application.routes.draw do
  root "pages#home"
  get "privacy", to: "pages#privacy"
  get "thanks", to: "pages#thanks"
  get "people/new", to: "submissions#new", as: :new_person
  post "people", to: "submissions#create", as: :people
  get "organisations/new", to: "submissions#new", as: :new_organisation
  post "organisations", to: "submissions#create", as: :organisations

  namespace :admin do
    root "submissions#index"
    resources :submissions, only: [ :index, :show, :update ]
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
