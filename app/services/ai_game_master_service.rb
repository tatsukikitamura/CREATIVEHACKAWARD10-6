class AiGameMasterService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      request_timeout: 60
    )
  end

  def generate_story_scene(story_state, story_mode = 'adventure')
    return generate_fallback_scene if ENV['OPENAI_API_KEY'].blank?

    # 物語モードに応じた設定
    story_settings = {
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        context: '暗い夜道、古い屋敷、謎めいた出来事の世界',
        goal_templates: [
          '呪われた館から脱出する',
          '古い屋敷の謎を解く',
          '悪霊の呪いを解く',
          '失われた魂を救う'
        ]
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        context: '未知の土地、宝物探し、危険な挑戦の世界',
        goal_templates: [
          '失われた宝物を見つける',
          '古代の遺跡を探索する',
          '伝説の剣を手に入れる',
          '魔法の王国を救う'
        ]
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        context: '謎めいた事件、隠された真実、複雑な人間関係の世界',
        goal_templates: [
          '殺人事件の真相を解明する',
          '盗まれた宝石を取り戻す',
          'スパイの正体を暴く',
          '組織の陰謀を阻止する'
        ]
      }
    }
    
    story = story_settings[story_mode] || story_settings['adventure']
    
    # 初期状態の場合は目標を設定
    if story_state['progress'].nil? || story_state['progress'] == 0
      story_state['goal'] = story[:goal_templates].sample
      story_state['progress'] = 0
      story_state['inventory'] = []
      story_state['flags'] = {}
      story_state['history'] = []
    end

    prompt = build_game_master_prompt(story_state, story)
    Rails.logger.info "[AI GM] Scene Prompt Generated:\n#{prompt}"
    
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは、MBTI性格診断を目的としたインタラクティブ・ノベルの優れたゲームマスターです。物語の進行管理と選択肢生成を担当し、プレイヤーの性格特性を測るための魅力的な物語を展開してください。必ず指定のJSON形式で回答し、他のテキストは含めないでください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.8,
        max_tokens: 1000
      }
    )

    parse_scene_response(response)
  rescue => e
    Rails.logger.error "AI Game Master Error: #{e.message}"
    generate_fallback_scene
  end

  def process_player_choice(story_state, choice_value, progress_impact)
    # 進捗を安全に更新
    current_progress = story_state['progress'] || 0
    new_progress = [current_progress + progress_impact, 100].min
    story_state['progress'] = new_progress
    
    # 選択を履歴に追加
    choice_description = generate_choice_description(choice_value, story_state)
    story_state['history'] ||= []
    story_state['history'] << choice_description
    
    # エンディングに到達したかチェック
    if story_state['progress'] >= 100
      # エンディングに到達した場合は、story_stateにエンディング情報を追加
      ending_data = generate_ending(story_state)
      story_state['ending_data'] = ending_data
    end
    
    story_state
  end

  def generate_ending(story_state)
    return generate_fallback_ending if ENV['OPENAI_API_KEY'].blank?

    prompt = build_ending_prompt(story_state)
    Rails.logger.info "[AI GM] Ending Prompt Generated:\n#{prompt}"
    
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "あなたは物語作家です。プレイヤーの選択履歴を基に、壮大で満足感のあるエンディングを創作し、その過程で示された性格特性を分析してください。必ず指定のJSON形式で回答し、他のテキストは含めないでください。"
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1200
      }
    )

    parse_ending_response(response)
  rescue => e
    Rails.logger.error "AI Game Master Ending Error: #{e.message}"
    generate_fallback_ending
  end

  private

  def build_game_master_prompt(story_state, story)
    <<~PROMPT
      # あなたへの指示
      あなたは、MBTI性格診断を目的としたインタラクティブ・ノベルの優れたゲームマスターです。
      以下のルールと現在の物語の状態に基づいて、次の場面を描写し、プレイヤーの選択肢を生成してください。

      # ルール
      - 物語のジャンルは「#{story[:atmosphere]}」です。
      - プレイヤーを少しずつクリア条件に近づけてください。
      - 生成する選択肢は、必ずMBTIの4次元（E/I, S/N, T/F, J/P）のいずれかに関連付けてください。
      - 物語の一貫性を保ち、プレイヤーの選択が物語に影響を与えるようにしてください。
      - 回答は必ず以下のJSON形式で出力してください。

      # 現在の物語の状態
      #{story_state.to_json}

      # 出力形式
      {
        "scene_text": "（ここに次の場面のテキストを生成。物語の雰囲気を大切にし、プレイヤーを引き込む描写を心がけてください）",
        "question_dimension": "T_F",
        "choices": [
          { "text": "（ここに思考(T)的な選択肢を生成）", "value": "T", "progress_impact": 5 },
          { "text": "（ここに感情(F)的な選択肢を生成）", "value": "F", "progress_impact": 5 }
        ],
        "inventory_updates": ["新しいアイテム名"],
        "flag_updates": { "新しいフラグ": true }
      }
    PROMPT
  end

  def build_ending_prompt(story_state)
    <<~PROMPT
      # エンディング生成の指示
      プレイヤーが物語を完結させました。以下の情報を基に、壮大で満足感のあるエンディングを創作し、その過程で示された性格特性を分析してください。

      # 物語の情報
      - 目標: #{story_state['goal']}
      - 最終進捗: #{story_state['progress']}%
      - 持ち物: #{story_state['inventory']&.join(', ') || 'なし'}
      - 重要な出来事: #{story_state['flags']&.keys&.join(', ') || 'なし'}
      - 選択履歴: #{story_state['history']&.join(' → ') || 'なし'}

      # 出力形式
      {
        "ending_text": "（ここに壮大なエンディングテキストを生成）",
        "mbti_analysis": "（ここに選択履歴を基にしたMBTI分析を生成）",
        "personality_insights": "（ここに性格の洞察を生成）",
        "achievement": "（ここに達成したことを簡潔にまとめる）"
      }
    PROMPT
  end

  def parse_scene_response(response)
    content = response.dig("choices", 0, "message", "content")
    return generate_fallback_scene unless content

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)
      
      {
        scene_text: data["scene_text"],
        question_dimension: data["question_dimension"],
        choices: data["choices"],
        inventory_updates: data["inventory_updates"] || [],
        flag_updates: data["flag_updates"] || {}
      }
    rescue => e
      Rails.logger.error "Scene parsing error: #{e.message}"
      generate_fallback_scene
    end
  end

  def parse_ending_response(response)
    content = response.dig("choices", 0, "message", "content")
    return generate_fallback_ending unless content

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)
      
      {
        ending_text: data["ending_text"],
        mbti_analysis: data["mbti_analysis"],
        personality_insights: data["personality_insights"],
        achievement: data["achievement"]
      }
    rescue => e
      Rails.logger.error "Ending parsing error: #{e.message}"
      generate_fallback_ending
    end
  end

  def generate_choice_description(choice_value, story_state)
    dimension_descriptions = {
      'E' => '外向的な行動',
      'I' => '内向的な行動',
      'S' => '感覚的な判断',
      'N' => '直感的な判断',
      'T' => '論理的な思考',
      'F' => '感情的な判断',
      'J' => '計画的な行動',
      'P' => '柔軟な対応'
    }
    
    "#{dimension_descriptions[choice_value]}を選択"
  end

  def generate_fallback_scene
    {
      scene_text: "あなたは神秘的な森の中にいます。前方に2つの道が見えます。",
      question_dimension: "E_I",
      choices: [
        { text: "左の道を選ぶ（外向的）", value: "E", progress_impact: 5 },
        { text: "右の道を選ぶ（内向的）", value: "I", progress_impact: 5 }
      ],
      inventory_updates: [],
      flag_updates: {}
    }
  end

  def generate_fallback_ending
    {
      ending_text: "あなたは物語を無事に完結させました。",
      mbti_analysis: "あなたの選択から、バランスの取れた性格特性が読み取れます。",
      personality_insights: "様々な状況で適切な判断を下す能力があります。",
      achievement: "物語の主人公としての冒険を完遂しました。"
    }
  end
end
