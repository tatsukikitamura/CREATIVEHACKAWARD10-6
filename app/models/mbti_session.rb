# frozen_string_literal: true

# MBTI診断セッションを管理するモデル
class MbtiSession < ApplicationRecord
  validates :session_id, presence: true, uniqueness: true
  validates :current_question_index, presence: true, numericality: { greater_than_or_equal_to: 0 }

  serialize :questions, coder: JSON
  serialize :answers, coder: JSON

  # 各次元の質問数を追跡
  DIMENSIONS = %w[EI SN TF JP].freeze

  # 物語モードの定義
  STORY_MODES = {
    'horror' => 'ホラー',
    'adventure' => 'アドベンチャー',
    'mystery' => 'ミステリー'
  }.freeze

  def self.find_or_create_by_session_id(session_id)
    find_by(session_id: session_id) || create!(session_id: session_id)
  end

  def questions_array
    return [] if questions.blank?

    questions.map { |q| MbtiQuestion.new(q) }
  end

  def answers_array
    return [] if answers.blank?

    answers.compact
  end

  def add_answer(question_index, answer)
    self.answers ||= []
    self.answers[question_index] = answer
    self.current_question_index = question_index + 1
    save!
  end

  def complete!
    self.completed = true
    save!
  end

  def current_question
    return nil if questions_array.empty? || current_question_index >= questions_array.length

    questions_array[current_question_index]
  end

  def total_questions
    questions_array.length
  end

  # 進捗表示は削除（ランダム質問のため）

  # ランダムに次元を選択
  def random_dimension
    DIMENSIONS.sample
  end

  # 現在の質問番号を取得（1から開始）
  def current_question_number
    current_question_index + 1
  end

  # 診断を途中で終了できるかどうか（最低3問回答済み）
  def can_terminate_early?
    answers_array.length >= 3
  end

  # 診断が完了しているかどうか
  def fully_completed?
    completed? && answers_array.length >= 12
  end

  # 前回の回答を取得
  def last_answer
    return nil if answers_array.empty?

    answers_array.last
  end

  # 物語の進行状況を取得
  def story_progress
    answers_array.length
  end
end
