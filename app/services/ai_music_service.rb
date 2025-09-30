# frozen_string_literal: true

# AIを使用してMBTIタイプに基づいた音楽推薦を行うサービス
class AiMusicService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて音楽の提案を生成
  def generate_music_recommendations(mbti_type, answers, story_mode = 'adventure', custom_story = nil)
    prompt = build_music_prompt(mbti_type, answers, story_mode, custom_story)
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
  def generate_playlist_info(mbti_type, answers, story_mode = 'adventure', custom_story = nil)
    prompt = build_playlist_prompt(mbti_type, answers, story_mode, custom_story)
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

  def build_music_prompt(mbti_type, answers, story_mode = 'adventure', custom_story = nil)
    # 回答の詳細な要約を作成
    answer_details = answers.map do |a|
      choice_text = a[:choice] == 'A' ? a[:optionA] : a[:optionB]
      "#{a[:question]}: #{choice_text}"
    end.join("\n")

    # 物語の設定を構築
    story_context = build_story_context(story_mode, custom_story)

    <<~PROMPT
      MBTIタイプ: #{mbti_type}

      物語設定:
      #{story_context}

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
    PROMPT
  end

  def build_playlist_prompt(mbti_type, answers, story_mode = 'adventure', custom_story = nil)
    # 回答の詳細な要約を作成
    answer_details = answers.map do |a|
      choice_text = a[:choice] == 'A' ? a[:optionA] : a[:optionB]
      "#{a[:question]}: #{choice_text}"
    end.join("\n")

    # 物語の設定を構築
    story_context = build_story_context(story_mode, custom_story)

    <<~PROMPT
      MBTIタイプ: #{mbti_type}

      物語設定:
      #{story_context}

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
end
