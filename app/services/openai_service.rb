# frozen_string_literal: true

# OpenAI APIを使用してMBTI診断関連の機能を提供するサービス
class OpenaiService
  # 応答時間最適化のための設定
  FAST_MODEL = 'gpt-4o-mini'
  FAST_TEMPERATURE = 0.6  # やや低めで一貫性を保ちつつ速度向上
  FAST_MAX_TOKENS = 350   # 改善版プロンプト用に少し増加
  FAST_TIMEOUT = 30       # タイムアウト短縮

  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV.fetch('OPENAI_API_KEY', nil),
      request_timeout: FAST_TIMEOUT
    )
  end

  attr_reader :client

  # ============================================
  # Phase 1,2,3対応：改善版メソッド
  # ============================================

  # StoryContextBuilderを使用した改善版質問生成
  def generate_story_question_v2(
    dimension:,
    story_mode:,
    story_arc:,
    cumulative_context:,
    phase_instruction:,
    phase:,
    last_answer:,
    custom_story: nil
  )
    Rails.logger.info "Generating story question v2: dim=#{dimension}, phase=#{phase}, " \
                      "has_context=#{cumulative_context.present?}, has_last_answer=#{last_answer.present?}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    # 初回か継続かでプロンプトとシステムメッセージを分ける
    if last_answer.blank?
      prompt = OpenaiPrompts.first_story_prompt_v2(
        dimension: dimension,
        story_mode: story_mode,
        story_arc: story_arc,
        custom_story: custom_story
      )
      system_content = build_first_question_system_prompt(phase)
    else
      prompt = OpenaiPrompts.continuing_story_prompt_v2(
        dimension: dimension,
        story_mode: story_mode,
        story_arc: story_arc,
        cumulative_context: cumulative_context,
        phase_instruction: phase_instruction,
        last_answer: last_answer,
        custom_story: custom_story
      )
      system_content = build_continuing_system_prompt(phase)
    end

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          { role: 'system', content: system_content },
          { role: 'user', content: prompt }
        ],
        temperature: FAST_TEMPERATURE,
        max_tokens: FAST_MAX_TOKENS
      }
    )

    OpenaiParsers.parse_single_question_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    generate_fallback_single_question(dimension)
  end

  # ============================================
  # 旧バージョン（互換性のため維持）
  # ============================================

  def generate_continuing_story_mbti_question(dimension, question_number, story_mode, last_answer, story_progress,
                                              custom_story = nil)
    Rails.logger.info "Generating story question: dim=#{dimension}, q=#{question_number}, mode=#{story_mode}, " \
                      "has_last_answer=#{last_answer.present?}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    # 初回か継続かでプロンプトを分ける
    if last_answer.blank?
      # 初回：物語の導入
      prompt = OpenaiPrompts.first_story_prompt(
        dimension: dimension,
        story_mode: story_mode,
        custom_story: custom_story
      )
      system_content = '物語作家。物語の冒頭シーンを作成し、最初の選択を提示。JSON形式のみで回答。'
    else
      # 継続：前回の選択結果から展開
      prompt = OpenaiPrompts.continuing_story_prompt(
        dimension: dimension,
        question_number: question_number,
        story_mode: story_mode,
        story_progress: story_progress,
        last_answer: last_answer,
        custom_story: custom_story
      )
      system_content = '物語作家。前回の選択の「結果」として新たな状況を描写。' \
                       '場面説明の繰り返しは禁止。「その結果〜」のように自然につなげる。JSON形式のみ。'
    end

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          { role: 'system', content: system_content },
          { role: 'user', content: prompt }
        ],
        temperature: FAST_TEMPERATURE,
        max_tokens: FAST_MAX_TOKENS
      }
    )

    OpenaiParsers.parse_single_question_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    generate_fallback_single_question(dimension)
  end

  def generate_story_mbti_question(dimension, question_number, story_mode)
    Rails.logger.info "Generating story question: dim=#{dimension}, q=#{question_number}, mode=#{story_mode}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    prompt = OpenaiPrompts.story_prompt(dimension: dimension, question_number: question_number, story_mode: story_mode)

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          {
            role: 'system',
            content: 'あなたは心理学者兼物語作家。指定世界観で性格測定質問を作成。JSON形式のみで回答。'
          },
          { role: 'user', content: prompt }
        ],
        temperature: FAST_TEMPERATURE,
        max_tokens: FAST_MAX_TOKENS
      }
    )

    OpenaiParsers.parse_single_question_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    generate_fallback_single_question(dimension)
  end

  def generate_single_mbti_question(dimension, question_number)
    Rails.logger.info "Generating single question: dim=#{dimension}, q=#{question_number}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    prompt = OpenaiPrompts.single_prompt(dimension: dimension, question_number: question_number)

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          {
            role: 'system',
            content: '性格診断の専門家。JSON形式のみで回答。'
          },
          { role: 'user', content: prompt }
        ],
        temperature: FAST_TEMPERATURE,
        max_tokens: FAST_MAX_TOKENS
      }
    )

    OpenaiParsers.parse_single_question_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    generate_fallback_single_question(dimension)
  end

  def analyze_mbti_responses(answers)
    Rails.logger.info 'Starting OpenAI API call for MBTI analysis'

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, skipping analysis'
      return nil
    end

    prompt = build_analysis_prompt(answers)

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          {
            role: 'system',
            content: 'MBTIの専門家。回答を分析してMBTIタイプを判定。'
          },
          { role: 'user', content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 200
      }
    )

    parse_analysis_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    nil
  end

  def generate_detailed_analysis(answers, mbti_type)
    return nil if ENV['OPENAI_API_KEY'].blank?

    answers_text = answers.each_with_index.map do |a, i|
      "#{i + 1}. #{a[:question]} → #{a[:choice] == 'A' ? a[:optionA] : a[:optionB]} (#{a[:dimension]})"
    end.join("\n")

    prompt = <<~PROMPT
      対象: #{mbti_type}
      回答:
      #{answers_text}

      出力（JSONのみ）:
      {"type_details":"タイプの特徴・強み・弱み・傾向(200-300字)","answer_summary":"回答傾向の要約(150-250字)"}
    PROMPT

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          { role: 'system', content: 'MBTI専門家。指定JSONのみで返答。' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.5,
        max_tokens: 400
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    return nil if content.nil?

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)
      { type_details: data['type_details'], answer_summary: data['answer_summary'] }
    rescue StandardError => _e
      nil
    end
  end

  def generate_personalized_story_report(answers, mbti_type, story_mode = 'adventure')
    return nil if ENV['OPENAI_API_KEY'].blank?

    # 物語モードに応じた設定
    story_settings = {
      'horror' => { atmosphere: 'ホラー・スリラー', context: '暗い夜道、古い屋敷、謎めいた出来事' },
      'adventure' => { atmosphere: 'アドベンチャー・冒険', context: '未知の土地、宝物探し、危険な挑戦' },
      'mystery' => { atmosphere: 'ミステリー・推理', context: '謎めいた事件、隠された真実、複雑な人間関係' }
    }

    story = story_settings[story_mode] || story_settings['adventure']
    story_context = build_story_context_from_answers(answers, story_mode)

    prompt = <<~PROMPT
      結果: #{mbti_type} / モード: #{story[:atmosphere]}

      回答履歴:
      #{story_context}

      出力（JSONのみ）:
      {"story_analysis":"物語文脈での診断理由(300-400字)","personality_insights":"回答パターンからの性格特徴(200-300字)","growth_suggestions":"成長のヒント(150-250字)"}
    PROMPT

    response = @client.chat(
      parameters: {
        model: FAST_MODEL,
        messages: [
          { role: 'system', content: '心理学者兼物語作家。指定JSONのみで返答。' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.6,
        max_tokens: 600
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    return nil if content.nil?

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)
      {
        story_analysis: data['story_analysis'],
        personality_insights: data['personality_insights'],
        growth_suggestions: data['growth_suggestions']
      }
    rescue StandardError => _e
      nil
    end
  end

  private

  # フェーズに応じた初回用システムプロンプト
  def build_first_question_system_prompt(phase)
    base = '物語作家。物語の冒頭シーンを作成し、最初の選択を提示。'

    phase_hint = case phase
                 when :opening
                   '世界観を丁寧に伝え、読者を物語に引き込む。'
                 else
                   ''
                 end

    "#{base}#{phase_hint}JSON形式のみで回答。"
  end

  # フェーズに応じた継続用システムプロンプト
  def build_continuing_system_prompt(phase)
    base = '物語作家。前回の選択の「結果」として新たな状況を描写。'

    phase_hint = case phase
                 when :opening
                   '穏やかなペースで世界観を広げる。'
                 when :rising
                   '緊張感を高め、問題が深刻化していく展開。'
                 when :climax
                   '最大の危機。劇的で緊迫した展開。これまでの選択が影響。'
                 when :falling
                   '解決への道筋が見え始める。希望と困難の交錯。'
                 when :resolution
                   '物語の締めくくり。選択の結果として結末へ向かう。'
                 else
                   ''
                 end

    "#{base}#{phase_hint}場面説明の繰り返しは禁止。「その結果〜」のように自然につなげる。JSON形式のみ。"
  end

  def build_story_context_from_answers(answers, story_mode)
    OpenaiPrompts.build_story_context_from_answers(answers, story_mode)
  end

  def generate_fallback_single_question(dimension)
    OpenaiFallbacks.generate_fallback_single_question(dimension)
  end

  def parse_questions_response(response)
    OpenaiParsers.parse_questions_response(response)
  end

  def parse_analysis_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return nil unless content

    # MBTIタイプを抽出（4文字の大文字の組み合わせ）
    mbti_match = content.match(/\b([EI][SN][TF][JP])\b/)
    mbti_match ? mbti_match[1] : nil
  end

  def build_analysis_prompt(answers)
    prompt = "以下の回答からMBTIタイプを判定:\n\n"

    answers.each_with_index do |answer, index|
      prompt += "#{index + 1}. #{answer[:question]} → #{answer[:choice] == 'A' ? answer[:optionA] : answer[:optionB]}\n"
    end

    prompt += "\nMBTIタイプ（INTJ, INTP等）を1つ回答。"
    prompt
  end

  def generate_fallback_questions
    OpenaiFallbacks.generate_fallback_questions
  end
end
