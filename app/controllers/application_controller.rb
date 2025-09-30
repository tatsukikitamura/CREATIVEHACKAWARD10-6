# frozen_string_literal: true

# アプリケーション全体のコントローラーの基底クラス
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end
