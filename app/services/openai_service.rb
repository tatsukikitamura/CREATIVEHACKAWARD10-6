# frozen_string_literal: true

# OpenAI APIを使用してMBTI診断関連の機能を提供するサービス
class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV.fetch('OPENAI_API_KEY', nil),
      request_timeout: 60
    )
  end

  attr_reader :client

  def generate_continuing_story_mbti_question(dimension, question_number, story_mode, last_answer, story_progress,
                                              custom_story = nil)
    Rails.logger.info 'Starting OpenAI API call for continuing story MBTI question generation'
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}, " \
                      "Mode: #{story_mode}, Progress: #{story_progress}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    # 次元に応じたプロンプトを作成
    info = OpenaiPrompts.dimension_info[dimension]
    story = OpenaiPrompts.story_settings(custom_story)[story_mode] || OpenaiPrompts.story_settings(custom_story)['adventure']

    # 前回の回答の情報を構築
    previous_context = OpenaiPrompts.build_previous_context(last_answer)

    # カスタム物語の情報を追加
    custom_info = OpenaiPrompts.build_custom_info(story_mode, custom_story)

    prompt = OpenaiPrompts.continuing_story_prompt(
      dimension: dimension,
      question_number: question_number,
      story_mode: story_mode,
      story_progress: story_progress,
      last_answer: last_answer,
      custom_story: custom_story
    )

    Rails.logger.info "Generated prompt: #{prompt[0..300]}..."

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは心理学者で、性格分析の専門家です。また、物語作家でもあります。' \
                     '指定された物語モードの世界観に沿って、前回の回答を踏まえた連続性のある物語で、' \
                     '性格や行動パターンを測る質問を作成してください。' \
                     '必ず有効なJSON形式で回答し、他のテキストは含めないでください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 700
      }
    )

    Rails.logger.info 'OpenAI API response received successfully'
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = OpenaiParsers.parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    generate_fallback_single_question(dimension)
  end

  def generate_story_mbti_question(dimension, question_number, story_mode)
    Rails.logger.info 'Starting OpenAI API call for story MBTI question generation'
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}, Mode: #{story_mode}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    # 次元に応じたプロンプトを作成
    prompt = OpenaiPrompts.story_prompt(dimension: dimension, question_number: question_number, story_mode: story_mode)

    Rails.logger.info "Generated prompt: #{prompt[0..200]}..."

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは心理学者で、性格分析の専門家です。また、物語作家でもあります。' \
                     '指定された物語モードの世界観に沿って、性格や行動パターンを測る質問を作成してください。' \
                     '必ず有効なJSON形式で回答し、他のテキストは含めないでください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 600
      }
    )

    Rails.logger.info 'OpenAI API response received successfully'
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = OpenaiParsers.parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    generate_fallback_single_question(dimension)
  end

  def generate_single_mbti_question(dimension, question_number)
    Rails.logger.info 'Starting OpenAI API call for single MBTI question generation'
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}"

    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn 'OpenAI API key not set, using fallback question'
      return generate_fallback_single_question(dimension)
    end

    # 次元に応じたプロンプトを作成
    prompt = OpenaiPrompts.single_prompt(dimension: dimension, question_number: question_number)

    Rails.logger.info "Generated prompt: #{prompt[0..200]}..."

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは心理学者で、性格分析の専門家です。正確で信頼性の高い性格診断テストの質問を作成してください。必ず有効なJSON形式で回答し、他のテキストは含めないでください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.8,
        max_tokens: 500
      }
    )

    Rails.logger.info 'OpenAI API response received successfully'
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = OpenaiParsers.parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
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
    Rails.logger.info "Analysis prompt: #{prompt[0..100]}..."

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたはMBTIの専門家です。ユーザーの回答を分析して、最も適切なMBTIタイプを判定してください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 500
      }
    )

    Rails.logger.info 'OpenAI API analysis response received successfully'
    parse_analysis_response(response)
  rescue StandardError => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    nil
  end

  private

  # 以降のパーサは OpenaiParsers に委譲

  public

  def generate_detailed_analysis(answers, mbti_type)
    return nil if ENV['OPENAI_API_KEY'].blank?

    prompt = <<~PROMPT
      あなたはMBTIの専門家です。以下の出力仕様に厳密に従ってください。

      対象タイプ: #{mbti_type}

      ユーザーの回答:
      #{answers.each_with_index.map do |a, i|
        "#{i + 1}. 質問: #{a[:question]}\n   回答: #{a[:choice] == 'A' ? a[:optionA] : a[:optionB]} " \
          "(次元: #{a[:dimension]})"
      end.join("\n")}

      出力仕様（必ずこのJSONのみを出力、他の文字や注釈は一切含めない）:
      {
        "type_details": "対象タイプの特徴、強み、弱み、キャリア傾向、人間関係の傾向を日本語で200〜300文字",
        "answer_summary": "上記の回答傾向を踏まえた要約を日本語で150〜250文字（具体的観察を含める）"
      }
    PROMPT

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          { role: 'system', content: 'あなたはMBTIと性格分析の専門家です。常に指定のJSONのみで返答してください。' },
          { role: 'user', content: prompt }
        ],
        temperature: 0.5,
        max_tokens: 700
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
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        narrative_style: '緊張感と恐怖感のある物語調',
        context: '暗い夜道、古い屋敷、謎めいた出来事の世界'
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        narrative_style: 'エキサイティングで冒険的な物語調',
        context: '未知の土地、宝物探し、危険な挑戦の世界'
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        narrative_style: '推理と分析が必要な物語調',
        context: '謎めいた事件、隠された真実、複雑な人間関係の世界'
      }
    }

    story = story_settings[story_mode] || story_settings['adventure']

    # 回答履歴から物語の流れを構築
    story_context = build_story_context_from_answers(answers, story_mode)

    prompt = <<~PROMPT
      あなたは心理学者であり、物語作家でもあります。ユーザーの回答履歴を物語の文脈で分析し、なぜこのMBTIタイプと診断されたのかを具体的に解説してください。

      診断結果: #{mbti_type}
      物語モード: #{story[:atmosphere]}
      物語の文脈: #{story[:context]}

      ユーザーの回答履歴（物語の選択）:
      #{story_context}

      出力仕様（必ずこのJSONのみを出力、他の文字や注釈は一切含めない）:
      {
        "story_analysis": "物語の文脈に沿って、なぜこのタイプと診断されたのかを具体的に解説" \
                          "（例：'あなたはアドベンチャーの物語で常に仲間を優先する選択をしました。" \
                          "これはあなたの「感情(F)」の特性を強く示しています...'）日本語で300〜400文字",
        "personality_insights": "回答パターンから見える性格の特徴や傾向を物語の選択として解説 日本語で200〜300文字",
        "growth_suggestions": "このタイプの特性を活かした成長のヒントを物語の冒険者としてのアドバイス形式で 日本語で150〜250文字"
      }
    PROMPT

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは心理学者で物語作家です。MBTIの専門知識と物語創作の才能を組み合わせて、' \
                     'ユーザーの回答を物語の文脈で分析し、説得力のある個人的なレポートを作成してください。' \
                     '常に指定のJSONのみで返答してください。'
          },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 1000
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
    prompt = "以下の質問に対する回答を分析して、MBTIタイプを判定してください：\n\n"

    answers.each_with_index do |answer, index|
      prompt += "#{index + 1}. #{answer[:question]}\n"
      prompt += "回答: #{answer[:choice] == 'A' ? answer[:optionA] : answer[:optionB]}\n\n"
    end

    prompt += '上記の回答に基づいて、最も適切なMBTIタイプ（INTJ, INTP, ENTJ, ENTP, INFJ, INFP, ' \
              'ENFJ, ENFP, ISTJ, ISFJ, ESTJ, ESFJ, ISTP, ISFP, ESTP, ESFPのいずれか）を判定してください。'

    prompt
  end

  def generate_fallback_questions
    OpenaiFallbacks.generate_fallback_questions
  end
end
