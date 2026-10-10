Rails.application.routes.draw do
  root "pages#home"
  resources :challenges, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :collaborator_invitations, only: [ :index, :create, :destroy ]
  end
  resource :invitation, only: [ :show, :update ]
  get "create-account", to: "sessions#create_account", as: :create_account
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  get "login/verify", to: "sessions#verify", as: :verify_login
  post "login/verify", to: "sessions#authenticate"
  delete "logout", to: "sessions#destroy", as: :logout
  get "dashboard", to: "dashboards#show", as: :dashboard
  patch "dashboard/profile", to: "dashboards#switch_profile", as: :switch_profile
  get "account/profile/edit", to: "submissions#edit", as: :edit_account_profile
  patch "account/profile", to: "submissions#update", as: :account_profile
  get "people", to: "directories#people"
  get "companies", to: "directories#companies", as: :companies

  get "sustainable-development-goals", to: "sdgs#index", as: :sdgs
  get "sustainable-development-goals/targets/:id", to: "sdgs#target", as: :sdg_target, constraints: { id: /[0-9]+\.[0-9a-z]+/ }, format: false
  get "sustainable-development-goals/:id", to: "sdgs#goal", as: :sdg_goal, constraints: { id: /[0-9]+/ }
  get "sdgs(/*path)", to: redirect { |_params, request| request.original_fullpath.sub(%r{\A/sdgs}, "/sustainable-development-goals") }, format: false
  get "quiz", to: "quiz#show", as: :quiz
  post "quiz", to: "quiz#create"
  get "quiz/explore", to: redirect("/quiz"), as: :explore_quiz
  post "quiz/explore", to: redirect("/quiz", status: 303)
  get "althomepage", to: "pages#althomepage"
  get "about", to: "pages#about"
  get "privacy", to: "pages#privacy"
  get "thanks", to: "pages#thanks"
  get "people/new", to: "submissions#new", as: :new_person
  post "people", to: "submissions#create"
  get "organisations/new", to: "submissions#new", as: :new_organisation
  post "organisations", to: "submissions#create", as: :organisations
  get "profiles/:slug/contact", to: "contact_requests#new", as: :new_profile_contact
  post "profiles/:slug/contact", to: "contact_requests#create", as: :profile_contact
  get "profiles/:slug/contact/thanks", to: "contact_requests#thanks", as: :profile_contact_thanks
  get "profiles/:slug", to: "profiles#show", as: :profile
  get "profiles/:slug/skills/:position", to: "profiles#skill", as: :profile_skill, constraints: { position: /[1-9][0-9]*/ }
  get "profiles/:slug/projects/:position", to: "profiles#project", as: :profile_project, constraints: { position: /[1-9][0-9]*/ }
  get "portfolio/images/:id", to: "portfolio_images#show", as: :portfolio_image
  get "portfolio/draft", to: "portfolio_images#draft", as: :draft_portfolio_image

  namespace :admin do
    root "submissions#index"
    resources :contact_requests, only: [ :index, :show ]
    resources :submissions, only: [ :index, :show, :update ]
    get "portfolio/images/:id", to: "submissions#image", as: :portfolio_image
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
