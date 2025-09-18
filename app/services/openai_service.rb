class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'] || 'your_api_key_here',
      request_timeout: 60
    )
  end

  def generate_mbti_questions
    prompt = MbtiQuestion.generate_questions

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは心理学者で、MBTI（Myers-Briggs Type Indicator）の専門家です。正確で信頼性の高い性格診断テストの質問を作成してください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 2000
      }
    )

    parse_questions_response(response)
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    generate_fallback_questions
  end

  def analyze_mbti_responses(answers)
    prompt = build_analysis_prompt(answers)

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたはMBTIの専門家です。ユーザーの回答を分析して、最も適切なMBTIタイプを判定してください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 500
      }
    )

    parse_analysis_response(response)
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    nil
  end

  private

  def parse_questions_response(response)
    content = response.dig("choices", 0, "message", "content")
    return generate_fallback_questions unless content

    begin
      questions_data = JSON.parse(content)
      questions_data.map do |q|
        MbtiQuestion.new(
          question: q['question'],
          options: [q['optionA'], q['optionB']],
          dimension: q['dimension']
        )
      end
    rescue JSON::ParserError
      generate_fallback_questions
    end
  end

  def parse_analysis_response(response)
    content = response.dig("choices", 0, "message", "content")
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

    prompt += "上記の回答に基づいて、最も適切なMBTIタイプ（INTJ, INTP, ENTJ, ENTP, INFJ, INFP, ENFJ, ENFP, ISTJ, ISFJ, ESTJ, ESFJ, ISTP, ISFP, ESTP, ESFPのいずれか）を判定してください。"
    
    prompt
  end

  def generate_fallback_questions
    # APIが利用できない場合のフォールバック質問
    [
      MbtiQuestion.new(
        question: "新しい人との出会いについてどう感じますか？",
        options: ["多くの人と会うのが楽しい", "少数の親しい人との時間を好む"],
        dimension: "EI"
      ),
      MbtiQuestion.new(
        question: "情報を処理する際、どちらを重視しますか？",
        options: ["具体的な事実と詳細", "全体的なパターンと可能性"],
        dimension: "SN"
      ),
      MbtiQuestion.new(
        question: "決定を下す際、何を重視しますか？",
        options: ["論理的な分析と客観性", "価値観と人間関係への影響"],
        dimension: "TF"
      ),
      MbtiQuestion.new(
        question: "日常生活でどちらを好みますか？",
        options: ["計画を立てて計画的に進める", "柔軟性を保って臨機応変に対応"],
        dimension: "JP"
      ),
      MbtiQuestion.new(
        question: "エネルギーをどこから得ますか？",
        options: ["人との交流や活動から", "一人の時間や内省から"],
        dimension: "EI"
      ),
      MbtiQuestion.new(
        question: "学習する際、どちらを好みますか？",
        options: ["段階的で体系的な方法", "全体的な理解から始める方法"],
        dimension: "SN"
      ),
      MbtiQuestion.new(
        question: "問題解決の際、どちらを重視しますか？",
        options: ["客観的な事実と論理", "人の感情や価値観"],
        dimension: "TF"
      ),
      MbtiQuestion.new(
        question: "締切についてどう感じますか？",
        options: ["締切を守るのは重要", "締切は柔軟に扱える"],
        dimension: "JP"
      ),
      MbtiQuestion.new(
        question: "会議やグループ活動についてどう感じますか？",
        options: ["活発に参加して意見を述べる", "聞き役に回ることが多い"],
        dimension: "EI"
      ),
      MbtiQuestion.new(
        question: "新しいアイデアについてどう感じますか？",
        options: ["実用的で実現可能なものを好む", "革新的で創造的なものを好む"],
        dimension: "SN"
      ),
      MbtiQuestion.new(
        question: "他人を評価する際、何を重視しますか？",
        options: ["能力と成果", "努力と動機"],
        dimension: "TF"
      ),
      MbtiQuestion.new(
        question: "旅行の計画についてどう感じますか？",
        options: ["詳細な計画を立てる", "大まかな計画で自由に行動"],
        dimension: "JP"
      )
    ]
  end
end
