# frozen_string_literal: true

# MBTI診断セッションを管理するモデル（キャッシュベース）
class MbtiSession
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :session_id, :string
  attribute :questions
  attribute :answers
  attribute :current_question_index, :integer, default: 0
  attribute :completed, :boolean, default: false
  attribute :story_mode, :string
  attribute :story_state
  attribute :custom_story
  attribute :created_at, :datetime
  attribute :updated_at, :datetime

  # デフォルト値を設定するメソッド
  def initialize(attributes = {})
    super
    self.questions ||= []
    self.answers ||= []
    self.story_state ||= {}
    self.custom_story ||= {}
  end

  validates :session_id, presence: true
  validates :current_question_index, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # 各次元の質問数を追跡
  DIMENSIONS = %w[EI SN TF JP].freeze

  # 物語モードの定義
  STORY_MODES = {
    'horror' => 'ホラー',
    'adventure' => 'アドベンチャー',
    'mystery' => 'ミステリー'
  }.freeze

  # キャッシュキーを生成
  def cache_key
    "mbti_session:#{session_id}"
  end

  # キャッシュから取得
  def self.find_by(session_id:)
    cached_data = Rails.cache.read("mbti_session:#{session_id}")
    return nil unless cached_data

    # シンボルキーと文字列キーの両方に対応
    data = if cached_data.is_a?(Hash)
             # シンボルキーを文字列キーに変換してからシンボルキーに戻す（ActiveModel::Attributes用）
             cached_data.symbolize_keys
           else
             cached_data
           end
    new(data)
  end

  # キャッシュに保存
  def save!
    raise ActiveModel::ValidationError, self unless valid?

    now = Time.current
    self.created_at ||= now
    self.updated_at = now

    # 属性をハッシュに変換（シンボルキーで保存）
    data = {}
    attribute_names.each do |name|
      value = public_send(name)
      # story_stateとcustom_storyは文字列キーのハッシュとして保存（JSONB互換性のため）
      data[name.to_sym] = if %i[story_state custom_story].include?(name)
                            value.is_a?(Hash) ? stringify_hash_keys(value) : value
                          else
                            value
                          end
    end
    data[:created_at] = created_at
    data[:updated_at] = updated_at

    Rails.cache.write(
      cache_key,
      data,
      expires_in: 24.hours # 24時間で期限切れ
    )
    true
  end

  # ハッシュのキーを文字列に変換（再帰的）
  def stringify_hash_keys(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), h|
        h[k.to_s] = stringify_hash_keys(v)
      end
    when Array
      value.map { |item| stringify_hash_keys(item) }
    else
      value
    end
  end

  # story_stateとcustom_storyを文字列キーでアクセスできるようにする
  def story_state
    value = read_attribute(:story_state)
    return {} unless value

    # シンボルキーを文字列キーに変換（コントローラーで文字列キーでアクセスしているため）
    value.is_a?(Hash) ? symbolize_to_string_keys(value) : value
  end

  def story_state=(value)
    # 文字列キーをシンボルキーに変換してから保存（内部ではシンボルキーで保存）
    normalized_value = if value.is_a?(Hash)
                         string_to_symbolize_keys(value)
                       else
                         value
                       end
    write_attribute(:story_state, normalized_value)
  end

  def custom_story
    value = read_attribute(:custom_story)
    return {} unless value

    value.is_a?(Hash) ? symbolize_to_string_keys(value) : value
  end

  def custom_story=(value)
    # 文字列キーをシンボルキーに変換してから保存（内部ではシンボルキーで保存）
    normalized_value = if value.is_a?(Hash)
                         string_to_symbolize_keys(value)
                       else
                         value
                       end
    write_attribute(:custom_story, normalized_value)
  end

  # シンボルキーを文字列キーに変換（再帰的）
  def symbolize_to_string_keys(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), h|
        h[k.to_s] = symbolize_to_string_keys(v)
      end
    when Array
      value.map { |item| symbolize_to_string_keys(item) }
    else
      value
    end
  end

  # 文字列キーをシンボルキーに変換（再帰的）
  def string_to_symbolize_keys(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), h|
        h[k.to_sym] = string_to_symbolize_keys(v)
      end
    when Array
      value.map { |item| string_to_symbolize_keys(item) }
    else
      value
    end
  end

  # 属性名のリストを取得
  def attribute_names
    %i[session_id questions answers current_question_index completed story_mode story_state custom_story created_at updated_at]
  end

  # 保存（エラー時は例外を発生させない）
  def save
    save!
  rescue ActiveModel::ValidationError
    false
  end

  # 更新
  def update!(attributes_hash)
    attributes_hash.each do |key, value|
      public_send("#{key}=", value)
    end
    save!
  end

  # 更新（エラー時は例外を発生させない）
  def update(attributes_hash)
    update!(attributes_hash)
  rescue ActiveModel::ValidationError
    false
  end

  # セッションを作成または取得
  def self.find_or_create_by_session_id(session_id)
    find_by(session_id: session_id) || begin
      new_session = new(session_id: session_id, current_question_index: 0, completed: false)
      new_session.save!
      new_session
    end
  end

  # セッションを作成
  def self.create!(attributes_hash = {})
    new_session = new(attributes_hash)
    new_session.save!
    new_session
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
    # 配列を拡張してから値を設定
    self.answers = answers.dup if answers.frozen?
    answers << nil while answers.length <= question_index
    answers[question_index] = answer
    self.current_question_index = question_index + 1
    save!
  end

  def complete!
    self.completed = true
    save!
  end

  def completed?
    completed == true
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
