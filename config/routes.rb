Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # MBTI診断アプリケーションのルート
  root 'mbti#index'
  get 'mbti', to: 'mbti#index'
  get 'mbti/mode_selection', to: 'mbti#mode_selection'
  get 'mbti/select_mode', to: 'mbti#select_mode'
  post 'mbti/set_mode', to: 'mbti#set_mode'
  get 'mbti/show', to: 'mbti#show'
  post 'mbti/answer', to: 'mbti#answer'
  post 'mbti/back', to: 'mbti#back'
  get 'mbti/result', to: 'mbti#result'
  get 'mbti/resume', to: 'mbti#resume'
  post 'mbti/analyze', to: 'mbti#analyze'
  post 'mbti/personalized_report', to: 'mbti#personalized_report'
  
  # AIゲームマスター方式のルート
  get 'mbti/game_master', to: 'mbti#game_master'
  post 'mbti/game_master/answer', to: 'mbti#game_master_answer'
  get 'mbti/game_master/ending', to: 'mbti#game_master_ending'
  
  # プロジェクト情報ページ
  get 'info', to: 'info#info'
end
