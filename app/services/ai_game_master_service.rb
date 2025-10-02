# frozen_string_literal: true

# AIを使用してゲームマスター機能を提供するサービス
class AiGameMasterService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV.fetch('OPENAI_API_KEY', nil),
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
        goal_templates: %w[
          呪われた館から脱出する
          古い屋敷の謎を解く
          悪霊の呪いを解く
          失われた魂を救う
        ]
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        context: '未知の土地、宝物探し、危険な挑戦の世界',
        goal_templates: %w[
          失われた宝物を見つける
          古代の遺跡を探索する
          伝説の剣を手に入れる
          魔法の王国を救う
        ]
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        context: '謎めいた事件、隠された真実、複雑な人間関係の世界',
        goal_templates: %w[
          殺人事件の真相を解明する
          盗まれた宝石を取り戻す
          スパイの正体を暴く
          組織の陰謀を阻止する
        ]
      }
    }

    story = story_settings[story_mode] || story_settings['adventure']

    # 初期状態の場合は目標を設定
    if story_state['progress'].nil? || story_state['progress'].zero?
      story_state['goal'] = story[:goal_templates].sample
      story_state['progress'] = 0
      story_state['inventory'] = []
      story_state['flags'] = {}
      story_state['history'] = []
      story_state['dimension_counts'] = {
        'E_I' => 0,
        'S_N' => 0,
        'T_F' => 0,
        'J_P' => 0
      }
    end

    # 現在のストーリー状態をインスタンス変数に保存
    @current_story_state = story_state

    prompt = build_game_master_prompt(story_state, story)
    Rails.logger.info "[AI GM] Scene Prompt Generated:\n#{prompt}"

    response = @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは、MBTI性格診断を目的としたインタラクティブ・ノベルの優れたゲームマスターです。' \
                     '物語の進行管理と選択肢生成を担当し、性格特性を測るための魅力的な物語を展開してください。' \
                     '必ず指定のJSON形式で回答し、他のテキストは含めないでください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.8,
        max_tokens: 1000
      }
    )

    parse_scene_response(response)
  rescue StandardError => e
    Rails.logger.error "AI Game Master Error: #{e.message}"
    generate_fallback_scene
  end

  def process_player_choice(story_state, choice_value, progress_impact, choice_text = nil)
    # 進捗を安全に更新
    current_progress = story_state['progress'] || 0
    new_progress = [current_progress + progress_impact, 100].min
    story_state['progress'] = new_progress

    # 選択を履歴に追加
    choice_description = choice_text || generate_choice_description(choice_value, story_state)
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
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは物語作家です。選択履歴を基に、壮大で満足感のあるエンディングを創作し、' \
                     'その過程で示された性格特性を分析してください。' \
                     'エンディングテキストでは「主人公」「あなた」「プレイヤー」などの主語を一切使用せず、' \
                     '「旅人」「探検者」「勇者」「冒険者」などの物語に適した呼び方を使用するか、' \
                     '主語を省略した文章構造にしてください。' \
                     '必ず指定のJSON形式で回答し、他のテキストは含めないでください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.7,
        max_tokens: 1200
      }
    )

    parse_ending_response(response)
  rescue StandardError => e
    Rails.logger.error "AI Game Master Ending Error: #{e.message}"
    generate_fallback_ending
  end

  private

  def build_game_master_prompt(story_state, story)
    <<~PROMPT
      # あなたへの指示
      あなたは、MBTI性格診断を目的としたインタラクティブ・ノベルの優れたゲームマスターです。
      以下のルールと現在の物語の状態に基づいて、次の場面を描写し、選択肢を生成してください。

      # ルール
      - 物語のジャンルは「#{story[:atmosphere]}」です。
      - 少しずつクリア条件に近づけてください。
      - 生成する選択肢は、必ずMBTIの4次元（E/I, S/N, T/F, J/P）のいずれかに関連付けてください。
      - 物語の一貫性を保ち、選択が物語に影響を与えるようにしてください。
      - 場面のテキストと選択肢は簡潔にし、「主人公」「あなた」などの主語は避けてください。
      - 各場面で異なる次元の質問を生成し、バランスよく4つの次元をカバーしてください。
      - 各次元は最大5回まで使用可能です。5回使用された次元は除外してください。
      - 次元の選択指針：
        * E_I（外向性/内向性）：人との関わり方、エネルギー源、社交性
        * S_N（感覚/直感）：情報の受け取り方、現実vs可能性、詳細vs全体
        * T_F（思考/感情）：意思決定の基準、論理vs価値観、客観vs主観
        * J_P（判断/知覚）：生活スタイル、計画性vs柔軟性、構造vs適応
      - 選択肢のテキストには、アルファベット表記（例：(T)、(F)、(E)、(I)など）を含めないでください。
      - 選択肢は自然で分かりやすい表現にしてください。
      - 回答は必ず以下のJSON形式で出力してください。

      # 現在の物語の状態
      #{story_state.to_json}

      # 利用可能な次元（使用回数に基づく）
      #{available_dimensions = get_available_dimensions(story_state)}
      利用可能な次元: #{available_dimensions.join(', ')}
      選択された次元: #{selected_dimension = available_dimensions.sample}

      # 出力形式
      {
        "scene_text": "（ここに次の場面のテキストを生成。物語の雰囲気を大切にし、引き込む描写を心がけてください）",
        "question_dimension": "#{selected_dimension}",
        "choices": [
          { "text": "（ここに選択肢Aを生成。アルファベット表記は含めない）", "value": "（Aの値：E, I, S, N, T, F, J, Pのいずれか）", "progress_impact": 5 },
          { "text": "（ここに選択肢Bを生成。アルファベット表記は含めない）", "value": "（Bの値：E, I, S, N, T, F, J, Pのいずれか）", "progress_impact": 5 }
        ],
        "inventory_updates": ["新しいアイテム名"],
        "flag_updates": { "新しいフラグ": true }
      }
    PROMPT
  end

  def build_ending_prompt(story_state)
    <<~PROMPT
      # エンディング生成の指示
      物語が完結しました。以下の情報を基に、壮大で満足感のあるエンディングを創作し、その過程で示された性格特性を分析してください。

      # 重要な注意事項
      - エンディングテキストでは「主人公」「あなた」「プレイヤー」などの主語を一切使用しないでください
      - 代わりに「旅人」「探検者」「勇者」「冒険者」などの物語に適した呼び方を使用するか、主語を省略した文章構造にしてください
      - 文章は三人称視点で、客観的で物語的な表現を心がけてください

      # 物語の情報
      - 目標: #{story_state['goal']}
      - 最終進捗: #{story_state['progress']}%
      - 持ち物: #{story_state['inventory']&.join(', ') || 'なし'}
      - 重要な出来事: #{story_state['flags']&.keys&.join(', ') || 'なし'}
      - 選択履歴: #{story_state['history']&.join(' → ') || 'なし'}

      # 出力形式
      {
        "ending_text": "（ここに壮大なエンディングテキストを生成。主語は使用せず、物語的な表現で）",
        "mbti_analysis": "（ここに選択履歴を基にしたMBTI分析を生成）",
        "personality_insights": "（ここに性格の洞察を生成）",
        "achievement": "（ここに達成したことを簡潔にまとめる）"
      }
    PROMPT
  end

  def parse_scene_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return generate_fallback_scene unless content

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)
      
      # 次元を強制的に設定（利用可能な次元からランダム選択）
      available_dimensions = get_available_dimensions(@current_story_state)
      selected_dimension = available_dimensions.sample
      data['question_dimension'] = selected_dimension
      
      # 選択された次元の使用回数を更新
      @current_story_state['dimension_counts'] ||= {
        'E_I' => 0,
        'S_N' => 0,
        'T_F' => 0,
        'J_P' => 0
      }
      @current_story_state['dimension_counts'][selected_dimension] += 1

      {
        scene_text: data['scene_text'],
        question_dimension: data['question_dimension'],
        choices: data['choices'],
        inventory_updates: data['inventory_updates'] || [],
        flag_updates: data['flag_updates'] || {}
      }
    rescue StandardError => e
      Rails.logger.error "Scene parsing error: #{e.message}"
      generate_fallback_scene
    end
  end

  def parse_ending_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return generate_fallback_ending unless content

    begin
      json_match = content.match(/\{[\s\S]*\}/)
      json_str = json_match ? json_match[0] : content
      data = JSON.parse(json_str)

      {
        ending_text: data['ending_text'],
        mbti_analysis: data['mbti_analysis'],
        personality_insights: data['personality_insights'],
        achievement: data['achievement']
      }
    rescue StandardError => e
      Rails.logger.error "Ending parsing error: #{e.message}"
      generate_fallback_ending
    end
  end

  def generate_choice_description(choice_value, _story_state)
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
    # ランダムに次元を選択
    dimensions = ['E_I', 'S_N', 'T_F', 'J_P']
    selected_dimension = dimensions.sample
    
    case selected_dimension
    when 'E_I'
      {
        scene_text: '神秘的な森の中。前方に2つの道が見える。',
        question_dimension: 'E_I',
        choices: [
          { text: '左の道を選ぶ', value: 'E', progress_impact: 5 },
          { text: '右の道を選ぶ', value: 'I', progress_impact: 5 }
        ],
        inventory_updates: [],
        flag_updates: {}
      }
    when 'S_N'
      {
        scene_text: '古い建物の前。扉の向こうから不思議な音が聞こえる。',
        question_dimension: 'S_N',
        choices: [
          { text: '音の正体を調べる', value: 'S', progress_impact: 5 },
          { text: '音の意味を想像する', value: 'N', progress_impact: 5 }
        ],
        inventory_updates: [],
        flag_updates: {}
      }
    when 'T_F'
      {
        scene_text: '困っている人を見かけた。助けるべきか迷っている。',
        question_dimension: 'T_F',
        choices: [
          { text: '論理的に判断する', value: 'T', progress_impact: 5 },
          { text: '感情で判断する', value: 'F', progress_impact: 5 }
        ],
        inventory_updates: [],
        flag_updates: {}
      }
    when 'J_P'
      {
        scene_text: '予期せぬ状況に遭遇した。どう対応するか決めなければならない。',
        question_dimension: 'J_P',
        choices: [
          { text: '計画を立てる', value: 'J', progress_impact: 5 },
          { text: '柔軟に対応する', value: 'P', progress_impact: 5 }
        ],
        inventory_updates: [],
        flag_updates: {}
      }
    end
  end

  def generate_fallback_ending
    {
      ending_text: '物語が無事に完結した。',
      mbti_analysis: '選択から、バランスの取れた性格特性が読み取れる。',
      personality_insights: '様々な状況で適切な判断を下す能力がある。',
      achievement: '冒険を完遂した。'
    }
  end

  def get_available_dimensions(story_state)
    # 次元の使用回数を取得
    dimension_counts = story_state['dimension_counts'] || {
      'E_I' => 0,
      'S_N' => 0,
      'T_F' => 0,
      'J_P' => 0
    }
    
    # 5回未満の次元のみを返す
    available = dimension_counts.select { |_, count| count < 5 }.keys
    
    # 全ての次元が5回使用された場合は、全てをリセット
    if available.empty?
      available = ['E_I', 'S_N', 'T_F', 'J_P']
      # 次元カウントをリセット
      story_state['dimension_counts'] = {
        'E_I' => 0,
        'S_N' => 0,
        'T_F' => 0,
        'J_P' => 0
      }
    end
    
    available
  end
end
