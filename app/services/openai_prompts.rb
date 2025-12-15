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

  # 詳細化されたストーリー設定
  def story_settings(custom_story = nil)
    {
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        opening: '不気味な古い屋敷に足を踏み入れた。扉が背後で閉まる音がする',
        tone: '緊張感と恐怖',
        time_period: '現代',
        world_rules: '超自然的な力が働く世界',
        key_elements: '不気味な音、影、謎のメッセージ、追跡者',
        protagonist: '事件に巻き込まれた者',
        choice_guidance: {
          'EI' => '他者と協力 vs 一人で行動',
          'SN' => '目に見える危険に対処 vs 見えない脅威を察知',
          'TF' => '論理的に脱出 vs 仲間の安否優先',
          'JP' => '計画的に行動 vs 即興で動く'
        }
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        opening: '古代遺跡の入口に立っている。伝説の秘宝がこの奥に眠っているという',
        tone: 'エキサイティングで冒険的',
        time_period: 'ファンタジー時代',
        world_rules: '勇気と知恵が報われる世界',
        key_elements: '古代の地図、トラップ、仲間、伝説の秘宝',
        protagonist: '冒険者・探検家',
        choice_guidance: {
          'EI' => 'チームで挑戦 vs 単独で冒険',
          'SN' => '地図や物証を頼る vs 直感を信じる',
          'TF' => '最適な戦略 vs 仲間の意見尊重',
          'JP' => '綿密な計画 vs 臨機応変'
        }
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        opening: '密室で事件が発生した。容疑者は全員この部屋にいる',
        tone: '推理と分析',
        time_period: '現代',
        world_rules: '全ての謎には論理的な解答がある',
        key_elements: '矛盾する証言、隠された動機、アリバイ',
        protagonist: '探偵・事件関係者',
        choice_guidance: {
          'EI' => '複数人から情報収集 vs 一人で証拠分析',
          'SN' => '物的証拠重視 vs 動機から推理',
          'TF' => '論理で犯人特定 vs 感情から嘘を見抜く',
          'JP' => '体系的捜査 vs 直感で動く'
        }
      },
      'creator' => build_creator_settings(custom_story)
    }
  end

  # カスタムストーリー設定を構築
  def build_creator_settings(custom_story)
    return default_creator_settings unless custom_story

    mood_mapping = {
      'dramatic' => { atmosphere: 'ドラマチック', tone: '感情の起伏が激しい' },
      'mysterious' => { atmosphere: 'ミステリアス', tone: '謎めいた雰囲気' },
      'adventure' => { atmosphere: 'アドベンチャー', tone: '冒険心を刺激' },
      'romantic' => { atmosphere: 'ロマンチック', tone: '心温まる感動' },
      'thriller' => { atmosphere: 'スリラー', tone: '緊迫した展開' },
      'comedy' => { atmosphere: 'コメディ', tone: '軽快で楽しい' }
    }

    time_period_mapping = {
      'modern' => '現代',
      'near_future' => '近未来',
      'far_future' => '遠い未来',
      'fantasy' => 'ファンタジー',
      'medieval' => '中世',
      'historical' => '歴史的'
    }

    mood_info = mood_mapping[custom_story['mood']] || { atmosphere: 'ドラマチック', tone: '冒険的' }
    time_period = time_period_mapping[custom_story['time_period']] || '不明'

    {
      atmosphere: mood_info[:atmosphere],
      opening: "#{custom_story['setting']}で物語が始まる。#{custom_story['theme']}という使命がある",
      tone: mood_info[:tone],
      time_period: time_period,
      world_rules: custom_story['theme'],
      key_elements: custom_story['key_items'] || '重要なアイテム',
      protagonist: custom_story['character_background'] || '主人公',
      protagonist_goal: custom_story['protagonist_goal'],
      choice_guidance: {
        'EI' => '他者と協力 vs 自分で考え行動',
        'SN' => '具体的事実重視 vs 可能性や直感',
        'TF' => '論理と効率優先 vs 感情と調和',
        'JP' => '計画通りに進める vs 柔軟に対応'
      }
    }
  end

  def default_creator_settings
    {
      atmosphere: 'ドラマチック',
      opening: '物語が始まる',
      tone: '冒険的',
      time_period: '不明',
      world_rules: '主人公の選択が物語を動かす',
      key_elements: '重要なアイテム',
      protagonist: '主人公',
      choice_guidance: {
        'EI' => '他者と協力 vs 自分で考え行動',
        'SN' => '具体的事実重視 vs 可能性や直感',
        'TF' => '論理と効率優先 vs 感情と調和',
        'JP' => '計画通りに進める vs 柔軟に対応'
      }
    }
  end

  # ============================================
  # Phase 1,2,3対応：改善版プロンプト
  # ============================================

  # 初回用プロンプト（物語の導入）- Phase対応版
  def first_story_prompt_v2(dimension:, story_mode:, story_arc:, custom_story: nil)
    info = dimension_info[dimension]
    story = story_settings(custom_story)[story_mode] || story_settings(custom_story)['adventure']
    guidance = story[:choice_guidance]&.dig(dimension) || ''

    <<~PROMPT
      #{story_arc}

      【物語設定】
      ジャンル: #{story[:atmosphere]}
      導入: #{story[:opening]}
      雰囲気: #{story[:tone]}

      【質問要件】
      次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      選択方向: #{guidance}

      【文章ルール】※厳守
      - question: 2〜3文、50〜80文字程度
      - 「あなた」「主人公」禁止。状況のみ描写
      - 選択肢: 10〜20文字で具体的行動
      - 読みやすく簡潔に

      良い例: 「古い屋敷の扉が閉まった。廊下の奥から物音が聞こえる。」
      悪い例: 「薄暗い廊下に立つあなたの背後で...（長文）」

      JSON出力:
      {"question":"簡潔な状況（50-80字）","optionA":"行動（10-20字）","optionB":"行動（10-20字）","dimension":"#{dimension}"}
    PROMPT
  end

  # 継続用プロンプト - Phase対応版（累積コンテキスト付き）
  def continuing_story_prompt_v2(
    dimension:,
    story_mode:,
    story_arc:,
    cumulative_context:,
    phase_instruction:,
    last_answer:,
    custom_story: nil
  )
    info = dimension_info[dimension]
    story = story_settings(custom_story)[story_mode] || story_settings(custom_story)['adventure']
    guidance = story[:choice_guidance]&.dig(dimension) || ''
    chosen_action = last_answer['choice'] == 'A' ? last_answer['optionA'] : last_answer['optionB']

    context_section = cumulative_context.present? ? "\n#{cumulative_context}\n" : ''

    <<~PROMPT
      #{story_arc}
      #{context_section}
      【前回】#{last_answer['question']} → 「#{chosen_action}」

      【次の質問】
      「#{chosen_action}」した結果、何が起きた？→ 新たな選択へ

      フェーズ: #{phase_instruction}
      次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      選択方向: #{guidance}

      【文章ルール】※厳守
      - question: 2〜3文、50〜80文字程度
      - 「あなた」「主人公」禁止。結果と状況のみ描写
      - 「その結果〜」「すると〜」で前回からつなげる
      - 場面説明の繰り返し禁止
      - 選択肢: 10〜20文字で具体的行動

      良い例: 「扉を開けると、奥から冷たい風が吹いてきた。二つの通路が見える。」
      悪い例: 「あなたが扉を開けると...（長文）」

      JSON出力:
      {"question":"結果と状況（50-80字）","optionA":"行動（10-20字）","optionB":"行動（10-20字）","dimension":"#{dimension}"}
    PROMPT
  end

  # ============================================
  # 旧バージョン（互換性のため維持）
  # ============================================

  # 初回用プロンプト（物語の導入）
  def first_story_prompt(dimension:, story_mode:, custom_story: nil)
    info = dimension_info[dimension]
    story = story_settings(custom_story)[story_mode] || story_settings(custom_story)['adventure']
    guidance = story[:choice_guidance]&.dig(dimension) || ''

    <<~PROMPT
      【物語の始まり】#{story[:atmosphere]}物語の最初の質問を作成。

      導入: #{story[:opening]}
      主人公: #{story[:protagonist]}
      雰囲気: #{story[:tone]}

      測定次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      選択の方向: #{guidance}

      【指示】
      - 物語冒頭の状況を描写（場面設定は1回だけ）
      - 最初の選択を迫る質問を作成
      - 主語「あなた」は不要、状況描写のみ
      - 選択肢は具体的な行動

      JSON出力:
      {"question":"冒頭の状況と最初の選択","optionA":"行動A","optionB":"行動B","dimension":"#{dimension}"}
    PROMPT
  end

  # 継続用プロンプト（前回の選択結果から展開）
  # rubocop:disable Lint/UnusedMethodArgument
  def continuing_story_prompt(dimension:, question_number:, story_mode:, story_progress:, last_answer:, custom_story: nil)
    # rubocop:enable Lint/UnusedMethodArgument
    info = dimension_info[dimension]
    story = story_settings(custom_story)[story_mode] || story_settings(custom_story)['adventure']
    guidance = story[:choice_guidance]&.dig(dimension) || ''

    # 前回の選択内容
    chosen_action = last_answer['choice'] == 'A' ? last_answer['optionA'] : last_answer['optionB']

    <<~PROMPT
      【物語の続き】前回の選択の結果から次の展開を作成。

      前回の状況: #{last_answer['question']}
      選んだ行動: 「#{chosen_action}」

      【重要】上記の選択の「結果」として何が起きたかを描写し、新たな選択を迫る。
      - 「#{chosen_action}」した結果、新しい状況が発生
      - 場面説明の繰り返しは不要（「古い屋敷で〜」等は書かない）
      - 「その結果〜」「すると〜」のように前回から自然につなげる

      測定次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      選択の方向: #{guidance}
      進行: #{story_progress}問目

      【指示】
      - 前回の行動の結果→新たな状況→次の選択、という流れ
      - 主語「あなた」不要
      - 選択肢は具体的な行動

      JSON出力:
      {"question":"前回の行動の結果と新たな選択","optionA":"行動A","optionB":"行動B","dimension":"#{dimension}"}
    PROMPT
  end

  # ストーリーモード用プロンプト（単発）
  def story_prompt(dimension:, question_number:, story_mode:)
    info = dimension_info[dimension]
    story = story_settings[story_mode] || story_settings['adventure']
    guidance = story[:choice_guidance]&.dig(dimension) || ''

    <<~PROMPT
      #{story[:atmosphere]}物語の質問を1つ生成。

      世界観: #{story[:world_rules]}
      主人公: #{story[:protagonist]}
      雰囲気: #{story[:tone]}

      次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      選択方向: #{guidance}
      質問番号: #{question_number}

      【指示】
      - 物語の一場面として自然な状況
      - 主語不要、状況描写のみ
      - 選択肢は具体的行動

      JSON出力:
      {"question":"状況質問","optionA":"行動A","optionB":"行動B","dimension":"#{dimension}"}
    PROMPT
  end

  def single_prompt(dimension:, question_number:)
    info = dimension_info[dimension]
    <<~PROMPT
      MBTI診断質問を1つ生成。

      次元: #{info[:name]}（A=#{info[:desc_a]}, B=#{info[:desc_b]}）
      質問番号: #{question_number}

      指示: 質問文は状況説明、選択肢は具体的行動（主語不要、簡潔に）

      JSON出力:
      {"question":"質問文","optionA":"#{info[:desc_a]}寄り","optionB":"#{info[:desc_b]}寄り","dimension":"#{dimension}"}
    PROMPT
  end

  def build_story_context_from_answers(answers, story_mode)
    story_settings_local = {
      'horror' => { choice_a: '立ち向かう', choice_b: '慎重に回避' },
      'adventure' => { choice_a: '勇敢に行動', choice_b: '慎重に判断' },
      'mystery' => { choice_a: '直感的推理', choice_b: '論理的分析' }
    }

    story = story_settings_local[story_mode] || story_settings_local['adventure']
    answers.each_with_index.map do |answer, i|
      choice_desc = answer[:choice] == 'A' ? story[:choice_a] : story[:choice_b]
      chosen = answer[:choice] == 'A' ? answer[:optionA] : answer[:optionB]
      "#{i + 1}. #{answer[:question]} → #{choice_desc}（#{chosen}）"
    end.join("\n")
  end
end
