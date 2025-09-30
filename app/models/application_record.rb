# frozen_string_literal: true

# アプリケーション全体のモデルの基底クラス
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
