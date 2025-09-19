class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      request_timeout: 60
    )
  end

  def generate_continuing_story_mbti_question(dimension, question_number, story_mode, last_answer, story_progress)
    Rails.logger.info "Starting OpenAI API call for continuing story MBTI question generation"
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}, Mode: #{story_mode}, Progress: #{story_progress}"
    
    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank? 
      Rails.logger.warn "OpenAI API key not set, using fallback question"
      return generate_fallback_single_question(dimension)
    end
    
    # 次元に応じたプロンプトを作成
    dimension_info = {
      'EI' => { name: '外向性/内向性', desc_a: '外向性', desc_b: '内向性' },
      'SN' => { name: '感覚/直感', desc_a: '感覚', desc_b: '直感' },
      'TF' => { name: '思考/感情', desc_a: '思考', desc_b: '感情' },
      'JP' => { name: '判断/知覚', desc_a: '判断', desc_b: '知覚' }
    }
    
    info = dimension_info[dimension]
    
    # 物語モードに応じた設定
    story_settings = {
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        setting: '暗い夜道、古い屋敷、謎めいた出来事',
        tone: '緊張感と恐怖感のある状況'
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        setting: '未知の土地、宝物探し、危険な挑戦',
        tone: 'エキサイティングで冒険的な状況'
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        setting: '謎めいた事件、隠された真実、複雑な人間関係',
        tone: '推理と分析が必要な状況'
      }
    }
    
    story = story_settings[story_mode] || story_settings['adventure']
    
    # 前回の回答の情報を構築
    previous_context = ""
    if last_answer
      previous_context = <<~CONTEXT
        前回の状況: #{last_answer['question']}
        あなたの選択: #{last_answer['choice'] == 'A' ? last_answer['optionA'] : last_answer['optionB']}
        その結果、物語は次の段階に進みました。
      CONTEXT
    end
    
    prompt = <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。
      
      物語モード: #{story[:atmosphere]}
      設定: #{story[:setting]}
      雰囲気: #{story[:tone]}
      
      次元: #{info[:name]}
      質問番号: #{question_number}
      物語の進行状況: #{story_progress}問目
      
      #{previous_context}
      
      前回の回答と選択に基づいて、物語を自然に続けてください。
      前回の状況から発展した新しいシチュエーションで、主人公の性格や行動パターンを測る質問を作成してください。
      物語の連続性を保ちながら、自然な状況で主人公の反応を測る質問にしてください。
      
      以下のJSON形式で1つの質問のみを出力してください：
      {
        "question": "前回の状況から続く物語の状況に基づいた質問文",
        "optionA": "選択肢A",
        "optionB": "選択肢B",
        "dimension": "#{dimension}"
      }
      
      重要: dimensionフィールドには必ず2文字の文字列（#{dimension}）を指定してください。
      1文字だけ（例: E, I, S, N, T, F, J, P）ではなく、必ず2文字のペア（例: EI, SN, TF, JP）で指定してください。
      
      必ず有効なJSON形式で出力し、他のテキストは含めないでください。
    PROMPT

    Rails.logger.info "Generated prompt: #{prompt[0..300]}..."

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは心理学者で、性格分析の専門家です。また、物語作家でもあります。指定された物語モードの世界観に沿って、前回の回答を踏まえた連続性のある物語で、主人公の性格や行動パターンを測る質問を作成してください。必ず有効なJSON形式で回答し、他のテキストは含めないでください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 700
      }
    )

    Rails.logger.info "OpenAI API response received successfully"
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    generate_fallback_single_question(dimension)
  end

  def generate_story_mbti_question(dimension, question_number, story_mode)
    Rails.logger.info "Starting OpenAI API call for story MBTI question generation"
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}, Mode: #{story_mode}"
    
    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank? 
      Rails.logger.warn "OpenAI API key not set, using fallback question"
      return generate_fallback_single_question(dimension)
    end
    
    # 次元に応じたプロンプトを作成
    dimension_info = {
      'EI' => { name: '外向性/内向性', desc_a: '外向性', desc_b: '内向性' },
      'SN' => { name: '感覚/直感', desc_a: '感覚', desc_b: '直感' },
      'TF' => { name: '思考/感情', desc_a: '思考', desc_b: '感情' },
      'JP' => { name: '判断/知覚', desc_a: '判断', desc_b: '知覚' }
    }
    
    info = dimension_info[dimension]
    
    # 物語モードに応じた設定
    story_settings = {
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        setting: '月明かりも届かない鬱蒼とした森の奥にある、埃をかぶった古い洋館。きしむ床板、壁に飾られた不気味な肖像画、そしてどこからともなく聞こえるささやき声。その屋敷の地下室には、決して開けてはならないと伝えられる鉄の扉がひっそりと隠されている。',
        tone: '息をひそめるような静けさの中に潜む、張り詰めた緊張感と得体の知れない恐怖。一瞬の油断も許されない、精神的に追い詰められる状況。主人公は、理性を失う寸前まで追い込まれながらも、恐怖の根源に迫っていく。'
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        setting: '古代文明の遺跡が眠る、地図にもない秘境のジャングル。巨大な滝の裏に隠された洞窟、罠が仕掛けられた神殿、そして絶滅したはずの生物が棲息する。その奥には、世界の歴史を書き換えるほどの力を秘めた伝説の秘宝が眠っている。',
        tone: '未知なるものを発見する高揚感と、常に隣り合わせの危険。困難を乗り越える勇気と、仲間との絆が試されるエキサイティングな状況。主人公は、失われた知識と技術を巡る壮大な冒険の中で、自らの限界に挑む。'
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        setting: '大雪で孤立した山荘。通信手段は断たれ、閉ざされた空間で次々と起こる不可解な殺人事件。容疑者は限られた人数、そしてそれぞれの心に秘められた嘘と動機。山荘に住む者たちの過去の因縁が、複雑に絡み合いながら事件の真相を隠蔽する。',
        tone: '緻密な思考と観察が要求される、知的な緊張感。誰も信じられない疑心暗鬼の中、真実を少しずつ解き明かしていく状況。主人公は、論理的な推理と鋭い洞察力で、完璧なアリバイと巧妙なトリックに立ち向かう。'
      }
    }
    
    story = story_settings[story_mode] || story_settings['adventure']
    
    prompt = <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。
      
      物語モード: #{story[:atmosphere]}
      設定: #{story[:setting]}
      雰囲気: #{story[:tone]}
      
      次元: #{info[:name]}
      質問番号: #{question_number}
      
      上記の物語モードの世界観に沿ったシチュエーションで、主人公の性格や行動パターンを測る質問を作成してください。
      質問は物語の一部として自然に感じられるように、具体的な状況設定を含めてください。
      
      以下のJSON形式で1つの質問のみを出力してください：
      {
        "question": "物語の状況に基づいた質問文",
        "optionA": "選択肢A",
        "optionB": "選択肢B",
        "dimension": "#{dimension}"
      }
      
      重要: dimensionフィールドには必ず2文字の文字列（#{dimension}）を指定してください。
      1文字だけ（例: E, I, S, N, T, F, J, P）ではなく、必ず2文字のペア（例: EI, SN, TF, JP）で指定してください。
      
      必ず有効なJSON形式で出力し、他のテキストは含めないでください。
    PROMPT

    Rails.logger.info "Generated prompt: #{prompt[0..200]}..."

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは心理学者で、性格分析の専門家です。また、物語作家でもあります。指定された物語モードの世界観に沿って、主人公の性格や行動パターンを測る質問を作成してください。必ず有効なJSON形式で回答し、他のテキストは含めないでください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 600
      }
    )

    Rails.logger.info "OpenAI API response received successfully"
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    generate_fallback_single_question(dimension)
  end

  def generate_single_mbti_question(dimension, question_number)
    Rails.logger.info "Starting OpenAI API call for single MBTI question generation"
    Rails.logger.info "Dimension: #{dimension}, Question number: #{question_number}"
    
    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank? 
      Rails.logger.warn "OpenAI API key not set, using fallback question"
      return generate_fallback_single_question(dimension)
    end
    
    # 次元に応じたプロンプトを作成
    dimension_info = {
      'EI' => { name: '外向性/内向性', desc_a: '外向性', desc_b: '内向性' },
      'SN' => { name: '感覚/直感', desc_a: '感覚', desc_b: '直感' },
      'TF' => { name: '思考/感情', desc_a: '思考', desc_b: '感情' },
      'JP' => { name: '判断/知覚', desc_a: '判断', desc_b: '知覚' }
    }
    
    info = dimension_info[dimension]
    
    prompt = <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。
      ()の内容は消してください
      
      次元: #{info[:name]}
      質問番号: #{question_number}
      
      以下のJSON形式で1つの質問のみを出力してください：
      {
        "question": "質問文",
        "optionA": "選択肢A（#{info[:desc_a]}を表す）",
        "optionB": "選択肢B（#{info[:desc_b]}を表す）",
        "dimension": "#{dimension}"
      }
      
      必ず有効なJSON形式で出力し、他のテキストは含めないでください。
    PROMPT

    Rails.logger.info "Generated prompt: #{prompt[0..200]}..."

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは心理学者で、性格分析の専門家です。正確で信頼性の高い性格診断テストの質問を作成してください。必ず有効なJSON形式で回答し、他のテキストは含めないでください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.8,
        max_tokens: 500
      }
    )

    Rails.logger.info "OpenAI API response received successfully"
    Rails.logger.info "Full API response: #{response.inspect}"
    parsed_question = parse_single_question_response(response)
    Rails.logger.info "Parsed question: #{parsed_question.inspect}"
    parsed_question
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    generate_fallback_single_question(dimension)
  end

  def analyze_mbti_responses(answers)
    Rails.logger.info "Starting OpenAI API call for MBTI analysis"
    
    # APIキーの確認
    if ENV['OPENAI_API_KEY'].blank?
      Rails.logger.warn "OpenAI API key not set, skipping analysis"
      return nil
    end
    
    prompt = build_analysis_prompt(answers)
    Rails.logger.info "Analysis prompt: #{prompt[0..100]}..."

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

    Rails.logger.info "OpenAI API analysis response received successfully"
    parse_analysis_response(response)
  rescue => e
    Rails.logger.error "OpenAI API Error: #{e.message}"
    Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
    nil
  end

  private

  def parse_single_question_response(response)
    Rails.logger.info "Parsing single question OpenAI response..."
    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info "Raw content from OpenAI: #{content}"
    
    return generate_fallback_single_question('EI') unless content

    begin
      # JSONの前後に余分なテキストがある場合を処理
      json_match = content.match(/\{.*\}/m)
      if json_match
        json_content = json_match[0]
        Rails.logger.info "Extracted JSON content: #{json_content}"
      else
        json_content = content
      end
      
      question_data = JSON.parse(json_content)
      Rails.logger.info "Successfully parsed JSON: #{question_data.inspect}"
      
      # 必須フィールドの確認
      unless question_data['question'] && question_data['optionA'] && question_data['optionB'] && question_data['dimension']
        Rails.logger.error "Missing required fields in question: #{question_data.inspect}"
        return generate_fallback_single_question(question_data['dimension'] || 'EI')
      end
      
      question = MbtiQuestion.new(
        question: question_data['question'],
        options: [question_data['optionA'], question_data['optionB']],
        dimension: question_data['dimension']
      )
      
      Rails.logger.info "Successfully created MbtiQuestion object"
      question
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      Rails.logger.error "Content that failed to parse: #{content}"
      generate_fallback_single_question('EI')
    rescue => e
      Rails.logger.error "Unexpected error during parsing: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
      generate_fallback_single_question('EI')
    end
  end

  def generate_fallback_single_question(dimension)
    fallback_questions = {
      'EI' => [
        { question: "新しい人との出会いについてどう感じますか？", optionA: "多くの人と会うのが楽しい", optionB: "少数の親しい人との時間を好む" },
        { question: "エネルギーをどこから得ますか？", optionA: "人との交流や活動から", optionB: "一人の時間や内省から" },
        { question: "会議やグループ活動についてどう感じますか？", optionA: "活発に参加して意見を述べる", optionB: "聞き役に回ることが多い" }
      ],
      'SN' => [
        { question: "情報を処理する際、どちらを重視しますか？", optionA: "具体的な事実と詳細", optionB: "全体的なパターンと可能性" },
        { question: "学習する際、どちらを好みますか？", optionA: "段階的で体系的な方法", optionB: "全体的な理解から始める方法" },
        { question: "新しいアイデアについてどう感じますか？", optionA: "実用的で実現可能なものを好む", optionB: "革新的で創造的なものを好む" }
      ],
      'TF' => [
        { question: "決定を下す際、何を重視しますか？", optionA: "論理的な分析と客観性", optionB: "価値観と人間関係への影響" },
        { question: "問題解決の際、どちらを重視しますか？", optionA: "客観的な事実と論理", optionB: "人の感情や価値観" },
        { question: "他人を評価する際、何を重視しますか？", optionA: "能力と成果", optionB: "努力と動機" }
      ],
      'JP' => [
        { question: "日常生活でどちらを好みますか？", optionA: "計画を立てて計画的に進める", optionB: "柔軟性を保って臨機応変に対応" },
        { question: "締切についてどう感じますか？", optionA: "締切を守るのは重要", optionB: "締切は柔軟に扱える" },
        { question: "旅行の計画についてどう感じますか？", optionA: "詳細な計画を立てる", optionB: "大まかな計画で自由に行動" }
      ]
    }
    
    questions = fallback_questions[dimension] || fallback_questions['EI']
    question_data = questions.sample
    
    MbtiQuestion.new(
      question: question_data[:question],
      options: [question_data[:optionA], question_data[:optionB]],
      dimension: dimension
    )
  end

  def parse_questions_response(response)
    Rails.logger.info "Parsing OpenAI response..."
    content = response.dig("choices", 0, "message", "content")
    Rails.logger.info "Raw content from OpenAI: #{content}"
    
    return generate_fallback_questions unless content

    begin
      # JSONの前後に余分なテキストがある場合を処理
      json_match = content.match(/\[.*\]/m)
      if json_match
        json_content = json_match[0]
        Rails.logger.info "Extracted JSON content: #{json_content}"
      else
        json_content = content
      end
      
      questions_data = JSON.parse(json_content)
      Rails.logger.info "Successfully parsed JSON: #{questions_data.inspect}"
      
      # データの検証
      unless questions_data.is_a?(Array) && questions_data.length > 0
        Rails.logger.error "Invalid data structure: expected array with questions"
        return generate_fallback_questions
      end
      
      parsed_questions = questions_data.map do |q|
        # 必須フィールドの確認
        unless q['question'] && q['optionA'] && q['optionB'] && q['dimension']
          Rails.logger.error "Missing required fields in question: #{q.inspect}"
          next
        end
        
        MbtiQuestion.new(
          question: q['question'],
          options: [q['optionA'], q['optionB']],
          dimension: q['dimension']
        )
      end.compact
      
      if parsed_questions.empty?
        Rails.logger.error "No valid questions created from OpenAI response"
        return generate_fallback_questions
      end
      
      Rails.logger.info "Successfully created #{parsed_questions.length} MbtiQuestion objects"
      parsed_questions
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      Rails.logger.error "Content that failed to parse: #{content}"
      generate_fallback_questions
    rescue => e
      Rails.logger.error "Unexpected error during parsing: #{e.message}"
      Rails.logger.error "Error details: #{e.backtrace.first(5).join("\n")}"
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

