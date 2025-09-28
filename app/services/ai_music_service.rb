class AiMusicService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて音楽の提案を生成
  def generate_music_recommendations(mbti_type, answers)
    begin
      prompt = build_music_prompt(mbti_type, answers)
      response = @openai_service.client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            {
              role: "system",
              content: "あなたは音楽の専門家です。MBTIタイプと回答に基づいて、その人に合う音楽ジャンル、アーティスト、楽曲を提案してください。"
            },
            {
              role: "user",
              content: prompt
            }
          ],
          max_tokens: 1000,
          temperature: 0.7
        }
      )

      content = response.dig("choices", 0, "message", "content")
      Rails.logger.info "Music recommendations response: #{content}"
      return parse_music_response(content) if content

      generate_fallback_music(mbti_type)
    rescue => e
      Rails.logger.error "Music generation error: #{e.message}"
      generate_fallback_music(mbti_type)
    end
  end

  # 音楽プレイリストの情報を生成
  def generate_playlist_info(mbti_type, answers)
    begin
      prompt = build_playlist_prompt(mbti_type, answers)
      response = @openai_service.client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            {
              role: "system",
              content: "あなたは音楽キュレーターです。MBTIタイプに基づいて、その人の性格に合うプレイリストのタイトル、説明、おすすめの楽曲を提案してください。"
            },
            {
              role: "user",
              content: prompt
            }
          ],
          max_tokens: 800,
          temperature: 0.8
        }
      )

      content = response.dig("choices", 0, "message", "content")
      Rails.logger.info "Playlist info response: #{content}"
      return parse_playlist_response(content) if content

      generate_fallback_playlist(mbti_type)
    rescue => e
      Rails.logger.error "Playlist generation error: #{e.message}"
      generate_fallback_playlist(mbti_type)
    end
  end

  private

  def build_music_prompt(mbti_type, answers)
    answer_summary = answers.map { |a| "#{a[:dimension]}: #{a[:choice]}" }.join(", ")
    
    <<~PROMPT
      MBTIタイプ: #{mbti_type}
      回答内容: #{answer_summary}
      
      この人の性格特性に基づいて、以下の形式で音楽の提案をしてください：
      
      ## おすすめジャンル
      - ジャンル1: 理由
      - ジャンル2: 理由
      
      ## おすすめアーティスト
      - アーティスト名: 楽曲例と理由
      
      ## おすすめ楽曲
      - 楽曲名 - アーティスト名: 理由
      
      ## 音楽の特徴
      - テンポ: 速い/中程度/遅い
      - ムード: 明るい/落ち着いた/エネルギッシュ/静か
      - 楽器: 主な楽器構成
    PROMPT
  end

  def build_playlist_prompt(mbti_type, answers)
    answer_summary = answers.map { |a| "#{a[:dimension]}: #{a[:choice]}" }.join(", ")
    
    <<~PROMPT
      MBTIタイプ: #{mbti_type}
      回答内容: #{answer_summary}
      
      この人の性格に合うプレイリストを作成してください：
      
      ## プレイリストタイトル
      [魅力的なタイトル]
      
      ## プレイリスト説明
      [このプレイリストのコンセプトと特徴]
      
      ## おすすめ楽曲（5-8曲）
      - 楽曲名 - アーティスト名
      
      ## プレイリストの雰囲気
      [全体的なムードと特徴]
    PROMPT
  end

  def parse_music_response(content)
    genres = extract_section(content, "おすすめジャンル")
    artists = extract_section(content, "おすすめアーティスト")
    songs = extract_section(content, "おすすめ楽曲")
    characteristics = extract_section(content, "音楽の特徴")
    
    Rails.logger.info "Parsed music data - genres: #{genres}, artists: #{artists}, songs: #{songs}, characteristics: #{characteristics}"
    
    {
      genres: genres,
      artists: artists,
      songs: songs,
      characteristics: characteristics
    }
  end

  def parse_playlist_response(content)
    {
      title: extract_section(content, "プレイリストタイトル")&.first,
      description: extract_section(content, "プレイリスト説明")&.first,
      songs: extract_section(content, "おすすめ楽曲"),
      mood: extract_section(content, "プレイリストの雰囲気")&.first
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
      elsif line.start_with?("##") && in_section
        break
      elsif in_section && line.strip.present?
        section_lines << line.strip
      end
    end
    
    # ハイフンで始まる行も含めて、ハイフンを削除して返す
    section_lines.map { |line| line.gsub(/^-\s*/, "").strip }.reject(&:blank?)
  end

  def generate_fallback_music(mbti_type)
    {
      genres: ["ポップス", "ロック", "ジャズ"],
      artists: ["人気アーティスト", "クラシックアーティスト"],
      songs: ["おすすめ楽曲1", "おすすめ楽曲2"],
      characteristics: ["バランスの取れた音楽", "多様なジャンル"]
    }
  end

  def generate_fallback_playlist(mbti_type)
    {
      title: "#{mbti_type}のためのプレイリスト",
      description: "あなたの性格に合った音楽のコレクション",
      songs: ["楽曲1", "楽曲2", "楽曲3"],
      mood: "バランスの取れた音楽体験"
    }
  end
end
