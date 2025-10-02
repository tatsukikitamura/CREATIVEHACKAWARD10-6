# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # MBTI診断アプリケーションのルート
  root 'mbti#index'
  get 'mbti', to: 'mbti#index'
  get 'mbti/mode_selection', to: 'mbti#mode_selection'
  get 'mbti/select_mode', to: 'mbti#select_mode'
  post 'mbti/set_mode', to: 'mbti#set_mode'
  get 'mbti/make_mode', to: 'mbti#make_mode'
  post 'mbti/create_story', to: 'mbti#create_story'
  get 'mbti/show', to: 'mbti#show'
  post 'mbti/answer', to: 'mbti#answer'
  post 'mbti/back', to: 'mbti#back'
  get 'mbti/result', to: 'mbti#result', as: 'mbti_result'
  get 'mbti/result_ai', to: 'mbti#result_ai', as: 'mbti_result_ai'
  get 'mbti/resume', to: 'mbti#resume'
  post 'mbti/analyze', to: 'mbti#analyze'
  post 'mbti/personalized_report', to: 'mbti#personalized_report'
  post 'mbti/generate_image', to: 'mbti#generate_image'
  post 'mbti/generate_music', to: 'mbti#generate_music'

  # AIゲームマスター方式のルート
  get 'mbti/game_master', to: 'mbti#game_master', as: 'mbti_game_master'
  post 'mbti/game_master/answer', to: 'mbti#game_master_answer', as: 'mbti_game_master_answer'
  get 'mbti/game_master/ending', to: 'mbti#game_master_ending', as: 'mbti_game_master_ending'

  # プロジェクト情報ページ
  get 'info', to: 'info#info'
end
