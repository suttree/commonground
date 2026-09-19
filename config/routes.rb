Rails.application.routes.draw do
  root "pages#home"
  get "sustainable-development-goals", to: "sdgs#index", as: :sdgs
  get "sustainable-development-goals/targets/:id", to: "sdgs#target", as: :sdg_target, constraints: { id: /[0-9]+\.[0-9a-z]+/ }, format: false
  get "sustainable-development-goals/:id", to: "sdgs#goal", as: :sdg_goal, constraints: { id: /[0-9]+/ }
  get "sdgs(/*path)", to: redirect { |_params, request| request.original_fullpath.sub(%r{\A/sdgs}, "/sustainable-development-goals") }, format: false
  get "quiz", to: "quiz#show", as: :quiz
  post "quiz", to: "quiz#create"
  get "quiz/explore", to: "quiz#explore", as: :explore_quiz
  post "quiz/explore", to: "quiz#select"
  get "althomepage", to: "pages#althomepage"
  get "about", to: "pages#about"
  get "privacy", to: "pages#privacy"
  get "thanks", to: "pages#thanks"
  get "people/new", to: "submissions#new", as: :new_person
  post "people", to: "submissions#create", as: :people
  get "organisations/new", to: "submissions#new", as: :new_organisation
  post "organisations", to: "submissions#create", as: :organisations
  get "profiles/:slug", to: "profiles#show", as: :profile
  get "profiles/:slug/skills/:position", to: "profiles#skill", as: :profile_skill, constraints: { position: /[1-9][0-9]*/ }
  get "profiles/:slug/projects/:position", to: "profiles#project", as: :profile_project, constraints: { position: /[1-9][0-9]*/ }
  get "portfolio/images/:id", to: "portfolio_images#show", as: :portfolio_image
  get "portfolio/draft", to: "portfolio_images#draft", as: :draft_portfolio_image

  namespace :admin do
    root "submissions#index"
    resources :submissions, only: [ :index, :show, :update ]
    get "portfolio/images/:id", to: "submissions#image", as: :portfolio_image
  end

  get "up", to: "rails/health#show", as: :rails_health_check
end
