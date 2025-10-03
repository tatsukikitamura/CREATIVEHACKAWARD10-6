# frozen_string_literal: true

# AIを使用してMBTIタイプに基づいた音楽推薦を行うサービス
class AiMusicService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて音楽の提案を生成
  def generate_music_recommendations(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    prompt = build_music_prompt(mbti_type, answers, story_mode, custom_story, story_context)
    response = @openai_service.client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは音楽の専門家です。MBTIタイプ、回答、そして物語の設定に基づいて、その人に合う音楽ジャンル、アーティスト、楽曲を提案してください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 1000,
        temperature: 0.7
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    Rails.logger.info "Music recommendations response: #{content}"
    return parse_music_response(content) if content

    generate_fallback_music(mbti_type)
  rescue StandardError => e
    Rails.logger.error "Music generation error: #{e.message}"
    generate_fallback_music(mbti_type)
  end

  # 音楽プレイリストの情報を生成
  def generate_playlist_info(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    prompt = build_playlist_prompt(mbti_type, answers, story_mode, custom_story, story_context)
    response = @openai_service.client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'あなたは音楽キュレーターです。MBTIタイプ、回答、そして物語の設定に基づいて、その人の性格に合うプレイリストのタイトル、説明、おすすめの楽曲を提案してください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 800,
        temperature: 0.8
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    Rails.logger.info "Playlist info response: #{content}"
    return parse_playlist_response(content) if content

    generate_fallback_playlist(mbti_type)
  rescue StandardError => e
    Rails.logger.error "Playlist generation error: #{e.message}"
    generate_fallback_playlist(mbti_type)
  end

  private

  def build_music_prompt(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    # 回答の詳細な要約を作成
    answer_details = answers.map do |a|
      choice_text = a[:choice] == 'A' ? a[:optionA] : a[:optionB]
      "#{a[:question]}: #{choice_text}"
    end.join("\n")

    # 物語の設定を構築
    base_story_context = build_story_context(story_mode, custom_story)
    enhanced_story_context = enhance_story_context_with_emotions(base_story_context, story_context)

    <<~PROMPT
      MBTIタイプ: #{mbti_type}

      物語設定:
      #{enhanced_story_context}

      回答履歴:
      #{answer_details}

      この人の性格特性と物語の文脈に基づいて、以下の形式で音楽の提案をしてください：

      ## おすすめジャンル
      - ジャンル名: 理由（物語の雰囲気と性格特性を考慮）
      - ジャンル名: 理由

      ## おすすめアーティスト
      - アーティスト名: 理由（物語の世界観と合致する理由）

      ## おすすめ楽曲
      - 楽曲名 - アーティスト名: 理由（物語のシーンに合う理由）

      ## 音楽の特徴
      - テンポ: 速い/中程度/遅い（物語のペースに合わせて）
      - ムード: 明るい/落ち着いた/エネルギッシュ/静か（物語の雰囲気に合わせて）
      - 楽器: 主な楽器構成（物語の世界観に合う楽器）
      - 動的調整: 物語の展開に応じた音楽の変化（緊張感、悲しみ、喜びなど）
    PROMPT
  end

  def build_playlist_prompt(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    # 回答の詳細な要約を作成
    answer_details = answers.map do |a|
      choice_text = a[:choice] == 'A' ? a[:optionA] : a[:optionB]
      "#{a[:question]}: #{choice_text}"
    end.join("\n")

    # 物語の設定を構築
    base_story_context = build_story_context(story_mode, custom_story)
    enhanced_story_context = enhance_story_context_with_emotions(base_story_context, story_context)

    <<~PROMPT
      MBTIタイプ: #{mbti_type}

      物語設定:
      #{enhanced_story_context}

      回答履歴:
      #{answer_details}

      この人の性格と物語の文脈に合うプレイリストを作成してください：

      ## プレイリストタイトル
      [物語の世界観と性格を反映した魅力的なタイトル]

      ## プレイリスト説明
      [このプレイリストのコンセプトと特徴（物語の雰囲気と性格特性を考慮）]

      ## おすすめ楽曲（3-5曲）
      - 楽曲名 - アーティスト名

      ## プレイリストの雰囲気
      [全体的なムードと特徴（物語の世界観と一致する雰囲気）]

      ## 物語の展開による音楽の変化
      [物語の重要な場面（困難な決断、悲しい結末など）に応じた音楽の動的調整]
    PROMPT
  end

  def parse_music_response(content)
    genres = extract_section(content, 'おすすめジャンル')
    artists = extract_section(content, 'おすすめアーティスト')
    songs = extract_section(content, 'おすすめ楽曲')
    characteristics = extract_section(content, '音楽の特徴')

    Rails.logger.info "Parsed music data - genres: #{genres}, artists: #{artists}, " \
                      "songs: #{songs}, characteristics: #{characteristics}"

    {
      genres: genres,
      artists: artists,
      songs: songs,
      characteristics: characteristics
    }
  end

  def parse_playlist_response(content)
    {
      title: extract_section(content, 'プレイリストタイトル')&.first,
      description: extract_section(content, 'プレイリスト説明')&.first,
      songs: extract_section(content, 'おすすめ楽曲'),
      mood: extract_section(content, 'プレイリストの雰囲気')&.first
    }
  end

  def extract_section(content, section_name)
    lines = content.split("\n")
    section_lines = []
    in_section = false

    lines.each do |line|
      if line.include?(section_name)
        in_section = true
        next
      elsif line.start_with?('##') && in_section
        break
      elsif in_section && line.strip.present?
        section_lines << line.strip
      end
    end

    # ハイフンで始まる行も含めて、ハイフンを削除して返す
    section_lines.map { |line| line.gsub(/^-\s*/, '').strip }.reject(&:blank?)
  end

  def generate_fallback_music(_mbti_type)
    {
      genres: %w[ポップス ロック ジャズ],
      artists: %w[人気アーティスト クラシックアーティスト],
      songs: %w[おすすめ楽曲1 おすすめ楽曲2],
      characteristics: %w[バランスの取れた音楽 多様なジャンル]
    }
  end

  def generate_fallback_playlist(mbti_type)
    {
      title: "#{mbti_type}のためのプレイリスト",
      description: 'あなたの性格に合った音楽のコレクション',
      songs: %w[楽曲1 楽曲2 楽曲3],
      mood: 'バランスの取れた音楽体験'
    }
  end

  def build_story_context(story_mode, custom_story)
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
      },
      'creator' => {
        atmosphere: custom_story&.dig('mood') || 'ドラマチック',
        setting: custom_story&.dig('setting') || '未知の世界',
        tone: custom_story&.dig('theme') || '冒険的な状況',
        character: custom_story&.dig('character_background')
      }
    }

    story = story_settings[story_mode] || story_settings['adventure']

    context = "舞台: #{story[:setting]}, 雰囲気: #{story[:atmosphere]}, トーン: #{story[:tone]}"
    context += ", キャラクター背景: #{story[:character]}" if story[:character]

    context
  end

  # 物語の展開による感情的な文脈を分析し、音楽生成に反映
  def enhance_story_context_with_emotions(base_context, story_context)
    return base_context unless story_context

    emotional_analysis = analyze_story_emotions(story_context)
    return base_context unless emotional_analysis

    "#{base_context}\n\n物語の感情的な展開:\n#{emotional_analysis}"
  end

  # 物語の展開から感情的な要素を分析
  def analyze_story_emotions(story_context)
    return nil unless story_context.is_a?(Hash)

    emotional_elements = []

    # 困難な決断の場面を検出
    if story_context['difficult_decisions'] || story_context['challenges']
      emotional_elements << "困難な決断: 主人公が重要な選択を迫られる場面では、緊張感を反映してBPMを少し速め、音楽にドラマチックな要素を追加"
    end

    # 悲しい結末を検出
    if story_context['sad_ending'] || story_context['tragic_elements']
      emotional_elements << "悲しい結末: 物語が悲しい結末を迎えた場合、音楽にメランコリックな要素を加え、アートの色彩をより深みのあるトーンに調整"
    end

    # 勝利や成功の場面を検出
    if story_context['victory'] || story_context['success']
      emotional_elements << "勝利の瞬間: 主人公が困難を乗り越えた場面では、音楽をより明るくエネルギッシュにし、アートに光と希望の要素を追加"
    end

    # 神秘的な要素を検出
    if story_context['mystery'] || story_context['magical_elements']
      emotional_elements << "神秘的な要素: 物語に神秘的な要素がある場合、音楽にアンビエントな要素を加え、アートに幻想的な色彩と抽象的な形状を追加"
    end

    emotional_elements.join("\n")
  end
end
