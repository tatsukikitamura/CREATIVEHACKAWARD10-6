# frozen_string_literal: true

module OpenaiPrompts
  module_function

  def dimension_info
    {
      'EI' => { name: '外向性/内向性', desc_a: '外向性', desc_b: '内向性' },
      'SN' => { name: '感覚/直感', desc_a: '感覚', desc_b: '直感' },
      'TF' => { name: '思考/感情', desc_a: '思考', desc_b: '感情' },
      'JP' => { name: '判断/知覚', desc_a: '判断', desc_b: '知覚' }
    }
  end

  def story_settings(custom_story = nil)
    {
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
      },
      'creator' => {
        atmosphere: custom_story&.dig('mood') || 'ドラマチック',
        setting: custom_story&.dig('setting') || '未知の世界',
        tone: custom_story&.dig('theme') || '冒険的な状況',
        character: custom_story&.dig('character_background')
      }
    }
  end

  def build_previous_context(last_answer)
    return '' unless last_answer
    <<~CONTEXT
      前回の状況: #{last_answer['question']}
      あなたの選択: #{last_answer['choice'] == 'A' ? last_answer['optionA'] : last_answer['optionB']}
      その結果、物語は次の段階に進みました。
    CONTEXT
  end

  def build_custom_info(story_mode, custom_story)
    return '' unless story_mode == 'creator' && custom_story
    <<~CUSTOM

      カスタム物語設定:
      舞台: #{custom_story['setting']}
      テーマ: #{custom_story['theme']}
      雰囲気: #{custom_story['mood']}
      #{"主人公の背景: #{custom_story['character_background']}" if custom_story['character_background']}
    CUSTOM
  end

  def continuing_story_prompt(dimension:, question_number:, story_mode:, story_progress:, last_answer:, custom_story: nil)
    info = dimension_info[dimension]
    story = story_settings(custom_story)[story_mode] || story_settings(custom_story)['adventure']
    previous_context = build_previous_context(last_answer)
    custom_info = build_custom_info(story_mode, custom_story)

    <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。

      物語モード: #{story[:atmosphere]}
      設定: #{story[:setting]}
      雰囲気: #{story[:tone]}#{custom_info}

      次元: #{info[:name]}
      質問番号: #{question_number}
      物語の進行状況: #{story_progress}問目

      #{previous_context}

      前回の回答と選択に基づいて、物語を自然に続けてください。
      前回の状況から発展した新しいシチュエーションで、性格や行動パターンを測る質問を作成してください。
      物語の連続性を保ちながら、自然な状況での反応を測る質問にしてください。
      
      質問文と選択肢は簡潔にし、「主人公」「あなた」などの主語は避けてください。
      質問文は状況を説明し、選択肢は具体的な行動や反応を簡潔に表現してください。

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
  end

  def story_prompt(dimension:, question_number:, story_mode:)
    info = dimension_info[dimension]
    story = story_settings[story_mode] || story_settings['adventure']
    <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。

      物語モード: #{story[:atmosphere]}
      設定: #{story[:setting]}
      雰囲気: #{story[:tone]}

      次元: #{info[:name]}
      質問番号: #{question_number}

      上記の物語モードの世界観に沿ったシチュエーションで、性格や行動パターンを測る質問を作成してください。
      質問は物語の一部として自然に感じられるように、具体的な状況設定を含めてください。
      
      質問文と選択肢は簡潔にし、「主人公」「あなた」などの主語は避けてください。
      質問文は状況を説明し、選択肢は具体的な行動や反応を簡潔に表現してください。

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
  end

  def single_prompt(dimension:, question_number:)
    info = dimension_info[dimension]
    <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を1つ生成してください。

      次元: #{info[:name]}
      質問番号: #{question_number}
      
      質問文と選択肢は簡潔にし、「主人公」「あなた」などの主語は避けてください。
      質問文は状況を説明し、選択肢は具体的な行動や反応を簡潔に表現してください。

      以下のJSON形式で1つの質問のみを出力してください：
      {
        "question": "質問文",
        "optionA": "選択肢A（#{info[:desc_a]}を表す）",
        "optionB": "選択肢B（#{info[:desc_b]}を表す）",
        "dimension": "#{dimension}"
      }

      必ず有効なJSON形式で出力し、他のテキストは含めないでください。
    PROMPT
  end

  def build_story_context_from_answers(answers, story_mode)
    story_settings = {
      'horror' => {
        context_prefix: '暗い夜道で遭遇した状況',
        choice_descriptions: { 'A' => '恐怖に立ち向かう選択', 'B' => '慎重に回避する選択' }
      },
      'adventure' => {
        context_prefix: '冒険の旅路で直面した選択',
        choice_descriptions: { 'A' => '勇気ある行動', 'B' => '慎重な判断' }
      },
      'mystery' => {
        context_prefix: '謎めいた事件の調査過程',
        choice_descriptions: { 'A' => '直感的な推理', 'B' => '論理的な分析' }
      }
    }

    story = story_settings[story_mode] || story_settings['adventure']
    answers.each_with_index.map do |answer, i|
      choice_desc = story[:choice_descriptions][answer[:choice]]
      "#{i + 1}. #{story[:context_prefix]}: #{answer[:question]}\n   あなたの選択: #{choice_desc} " \
        "(#{answer[:choice] == 'A' ? answer[:optionA] : answer[:optionB]})"
    end.join("\n")
  end
end


