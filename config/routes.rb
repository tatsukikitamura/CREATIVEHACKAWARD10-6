Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # MBTI診断アプリケーションのルート
  root 'mbti#index'
  get 'mbti', to: 'mbti#index'
  get 'mbti/select_mode', to: 'mbti#select_mode'
  post 'mbti/set_mode', to: 'mbti#set_mode'
  get 'mbti/show', to: 'mbti#show'
  post 'mbti/answer', to: 'mbti#answer'
  get 'mbti/result', to: 'mbti#result'
  get 'mbti/resume', to: 'mbti#resume'
end
