# frozen_string_literal: true

# AIを使用してMBTIタイプに基づいた画像生成を行うサービス
class AiPhotoService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて画像のプロンプトを生成
  def generate_image_prompts(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    prompt = build_image_prompt(mbti_type, answers, story_mode, custom_story, story_context)
    response = @openai_service.client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'あなたは画像生成の専門家です。MBTIタイプと回答に基づいて、その人の性格を表現する画像のプロンプトを生成してください。'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 500,
        temperature: 0.9
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    return parse_image_response(content) if content

    generate_fallback_images(mbti_type)
  rescue StandardError => e
    Rails.logger.error "Image prompt generation error: #{e.message}"
    generate_fallback_images(mbti_type)
  end

  # 画像を生成（DALL·E 2 を使用）
  def generate_image_with_dalle(prompt, size = '1024x1024')
    Rails.logger.info "Generating image with prompt: #{prompt}"

    # 過度に長いプロンプトはAPI側でエラーになりやすいのでトリミング
    safe_prompt = prompt.to_s.strip
    safe_prompt = safe_prompt[0, 1800] if safe_prompt.length > 1800

    model = 'dall-e-2'
    last_error = nil

    2.times do |attempt|
      sleep(0.5 * (2**attempt)) if attempt.positive? # エクスポネンシャルバックオフ

      response = @openai_service.client.images.generate(
        parameters: {
          model: model,
          prompt: safe_prompt,
          size: size,
          n: 1
        }
      )

      # URL または base64 のいずれかに対応
      image_url = response.dig('data', 0, 'url')
      if image_url
        Rails.logger.info "Image generated successfully (#{model}): #{image_url}"
        return image_url
      end

      b64 = response.dig('data', 0, 'b64_json')
      if b64
        data_uri = "data:image/png;base64,#{b64}"
        Rails.logger.info "Image generated (base64, #{model})"
        return data_uri
      end

      Rails.logger.warn "No image data in response (#{model}): #{response}"
    rescue Faraday::ServerError, Faraday::TimeoutError => e
      last_error = e
      Rails.logger.warn "Transient error on #{model} attempt #{attempt + 1}: #{e.message}"
      next
    rescue StandardError => e
      last_error = e
      # OpenAIの画像APIエラー内容をできるだけ詳しくログに出す
      extra =
        if e.respond_to?(:response) && e.response.is_a?(Hash)
          body = e.response[:body]
          " | response_body=#{body}"
        else
          ''
        end
      Rails.logger.error "Image generation error on #{model}: #{e.message}#{extra}"
      break
    end

    Rails.logger.error "Image generation failed after retries: #{last_error&.message}"
    nil
  end

  # 複数の画像を生成
  def generate_multiple_images(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    prompts = generate_image_prompts(mbti_type, answers, story_mode, custom_story, story_context)
    images = []

    prompts[:prompts].each do |prompt_data|
      image_url = generate_image_with_dalle(prompt_data[:prompt])
      next unless image_url

      images << {
        url: image_url,
        title: prompt_data[:title],
        description: prompt_data[:description]
      }
    end

    images
  end

  # MBTIタイプに基づくデフォルト画像プロンプト
  def get_default_prompts_for_type(mbti_type)
    type_prompts = {
      'INTJ' => [
        'Abstract geometric patterns representing strategic thinking, dark blue and silver tones, analytical precision',
        'Mountain peak silhouette at sunrise, symbolic of vision and determination, minimalist composition',
        'Floating geometric shapes and mathematical symbols, representing complex analysis and knowledge'
      ],
      'INTP' => [
        'Abstract geometric patterns representing logical thinking, purple and blue tones, mathematical precision',
        'Floating books and digital elements in mysterious atmosphere, conceptual knowledge representation',
        'Abstract puzzle pieces and code fragments floating in space, representing deep analytical thought'
      ],
      'ENTJ' => [
        'Abstract power symbols and commanding geometric shapes, red and gold tones, leadership energy',
        'City skyline silhouette at sunset, representing ambition and success, minimalist urban composition',
        'Floating decision-making symbols and abstract business elements, representing strategic authority'
      ],
      'ENTP' => [
        'Abstract explosion of creative energy, colorful geometric shapes and dynamic patterns, bright vibrant colors',
        'Futuristic abstract cityscape with innovative architectural elements, dynamic and creative composition',
        'Floating light bulbs and idea symbols in energetic motion, representing enthusiastic innovation'
      ],
      'INFJ' => [
        'Abstract gentle light patterns through organic shapes, representing insight and wisdom, ' \
        'soft green and gold tones',
        'Flowing abstract water patterns and peaceful garden elements, serene and contemplative composition',
        'Floating heart symbols and helping hands in abstract form, representing compassion and understanding'
      ],
      'INFP' => [
        'Abstract dreamy watercolor patterns, artistic and emotional, soft pastel colors flowing together',
        'Magical abstract forest elements with soft ethereal lighting, imaginative and whimsical composition',
        'Floating artistic tools and creative symbols, representing inner emotional expression and artistic soul'
      ],
      'ENFJ' => [
        'Abstract warm community symbols and connecting elements, representing support and togetherness',
        'Sunrise abstract patterns over community silhouettes, representing hope and inspiration',
        'Floating teaching and mentoring symbols, representing caring guidance and encouragement'
      ],
      'ENFP' => [
        'Abstract explosion of vibrant colors and creative energy, spontaneous and dynamic patterns',
        'Multiple abstract paths and adventure symbols, exciting and open exploration composition',
        'Floating exploration symbols and curiosity elements, representing excitement and discovery'
      ],
      'ISTJ' => [
        'Abstract organized geometric patterns, representing perfect order and structure, reliable and methodical',
        'Stable abstract mountain silhouettes, solid and dependable composition, minimalist landscape',
        'Floating task completion symbols and precision elements, representing methodical work and reliability'
      ],
      'ISFJ' => [
        'Abstract cozy home symbols and nurturing elements, caring and warm earth tones',
        'Gentle abstract garden patterns with blooming flower elements, peaceful and supportive composition',
        'Floating care symbols and love elements, representing nurturing attention and support'
      ],
      'ESTJ' => [
        'Abstract efficient office symbols and productive elements, organized and professional tones',
        'Well-planned abstract city patterns with clear structure, reliable and systematic composition',
        'Floating leadership symbols and authority elements, representing competence and team management'
      ],
      'ESFJ' => [
        'Abstract happy family symbols and social elements, caring and warm inviting atmosphere',
        'Community celebration patterns and joyful elements, supportive and festive composition',
        'Floating event organization symbols and connection elements, representing bringing people together'
      ],
      'ISTP' => [
        'Abstract technical workshop symbols and tool elements, practical and hands-on mechanical patterns',
        'Adventure sports abstract symbols, independent and action-oriented dynamic composition',
        'Floating building and fixing symbols, representing skill and focused craftsmanship'
      ],
      'ISFP' => [
        'Abstract artistic studio elements and creative symbols, sensitive and aesthetic composition',
        'Natural abstract landscape patterns with artistic elements, peaceful and beautiful organic forms',
        'Floating beauty creation symbols and care elements, representing artistic attention and aesthetic focus'
      ],
      'ESTP' => [
        'Abstract dynamic action patterns, energetic and spontaneous, bold vibrant colors',
        'Adventure sports abstract symbols and outdoor elements, exciting and active composition',
        'Floating action symbols and energy elements, representing immediate confident movement'
      ],
      'ESFP' => [
        'Abstract vibrant party symbols and celebration elements, fun-loving and social bright colors',
        'Festive abstract outdoor patterns, joyful and energetic composition',
        'Floating entertainment symbols and charm elements, representing enthusiasm and social energy'
      ]
    }

    prompts = type_prompts[mbti_type] || type_prompts['INTJ']

    {
      prompts: [
        {
          title: '抽象的な表現',
          description: 'あなたの性格を抽象的に表現',
          prompt: "#{prompts[0]}. Abstract, symbolic, conceptual, artistic representation."
        },
        {
          title: '自然・風景での表現',
          description: 'あなたの性格を自然で表現',
          prompt: "#{prompts[1]}. Abstract, symbolic, conceptual, artistic representation."
        },
        {
          title: '日常シーンでの表現',
          description: 'あなたの性格を日常で表現',
          prompt: "#{prompts[2]}. Abstract, symbolic, conceptual, artistic representation."
        }
      ]
    }
  end

  private

  def build_image_prompt(mbti_type, answers, story_mode = 'adventure', custom_story = nil, story_context = nil)
    answer_summary = answers.map { |a| "#{a[:dimension]}: #{a[:choice]}" }.join(', ')

    # 物語の設定を構築
    story_context_text = build_story_context_for_images(story_mode, custom_story, story_context)

    <<~PROMPT
      MBTIタイプ: #{mbti_type}
      回答内容: #{answer_summary}

      物語設定:
      #{story_context_text}

      この人の性格特性と物語の文脈を表現する3つの異なる画像のプロンプトを生成してください：

      ## 抽象的な表現
      [性格の本質を抽象的に表現した画像のプロンプト]

      ## 自然・風景での表現
      [性格を自然や風景で表現した画像のプロンプト]

      ## 日常シーンでの表現
      [性格を日常のシーンで表現した画像のプロンプト]

      各プロンプトは英語で、DALL-Eで生成可能な形式で記述してください。
      プロンプトは具体的で、視覚的に魅力的な画像を生成できるようにしてください。

      【重要】画像生成の制約事項：
      - 抽象的な表現を重視し、具体的な物体や人物よりも概念的な視覚表現を心がけてください
      - 色彩、形状、質感、光と影の効果を活用して感情や性格を表現してください
      - 象徴的で詩的なイメージを生成し、直感的に理解できる視覚的メタファーを重視してください
      - 物語の展開に応じて、困難な決断の場面ではシャープな線を追加し、悲しい結末では深みのある色彩を使用してください
      - プロンプトの最後に必ず「Abstract, symbolic, conceptual, artistic representation」を追加してください
    PROMPT
  end

  def parse_image_response(content)
    lines = content.split("\n")
    prompts = []
    current_prompt = nil
    current_title = nil
    current_description = nil

    lines.each do |line|
      if line.start_with?('##')
        if current_prompt && current_title
          # プロンプトに抽象的な表現のルールを自動追加
          enhanced_prompt = "#{current_prompt.strip}. Abstract, symbolic, conceptual, artistic representation."
          prompts << {
            title: current_title,
            description: current_description,
            prompt: enhanced_prompt
          }
        end

        current_title = line.gsub(/^##\s*/, '')
        current_description = ''
        current_prompt = ''
      elsif line.strip.present? && !line.start_with?('#')
        if current_prompt.nil?
          current_prompt = line
        else
          current_prompt += " #{line}"
        end
      end
    end

    # 最後のプロンプトを追加
    if current_prompt && current_title
      # プロンプトに抽象的な表現のルールを自動追加
      enhanced_prompt = "#{current_prompt.strip}. Abstract, symbolic, conceptual, artistic representation."
      prompts << {
        title: current_title,
        description: current_description,
        prompt: enhanced_prompt
      }
    end

    { prompts: prompts }
  end

  def generate_fallback_images(mbti_type)
    {
      prompts: [
        {
          title: '抽象的な表現',
          description: 'あなたの性格を抽象的に表現',
          prompt: "Abstract art representing #{mbti_type} personality type, vibrant colors, modern style"
        },
        {
          title: '自然・風景での表現',
          description: 'あなたの性格を自然で表現',
          prompt: "Beautiful landscape representing #{mbti_type} personality, peaceful and inspiring"
        },
        {
          title: '日常シーンでの表現',
          description: 'あなたの性格を日常で表現',
          prompt: "Daily life scene representing #{mbti_type} personality, warm and inviting"
        }
      ]
    }
  end

  # 画像生成用の物語文脈を構築
  def build_story_context_for_images(story_mode, custom_story, story_context)
    base_context = build_base_story_context(story_mode, custom_story)
    enhance_image_context_with_emotions(base_context, story_context)
  end

  # 基本的な物語設定を構築
  def build_base_story_context(story_mode, custom_story)
    story_settings = {
      'horror' => {
        atmosphere: 'ホラー・スリラー',
        setting: '暗い夜道、古い屋敷、謎めいた出来事',
        tone: '緊張感と恐怖感のある状況',
        visual_style: '暗い色彩、シャープなコントラスト、神秘的な雰囲気'
      },
      'adventure' => {
        atmosphere: 'アドベンチャー・冒険',
        setting: '未知の土地、宝物探し、危険な挑戦',
        tone: 'エキサイティングで冒険的な状況',
        visual_style: '鮮やかな色彩、ダイナミックな構図、エネルギッシュな雰囲気'
      },
      'mystery' => {
        atmosphere: 'ミステリー・推理',
        setting: '謎めいた事件、隠された真実、複雑な人間関係',
        tone: '推理と分析が必要な状況',
        visual_style: '落ち着いた色彩、複雑な構図、知的な雰囲気'
      },
      'creator' => {
        atmosphere: custom_story&.dig('mood') || 'ドラマチック',
        setting: custom_story&.dig('setting') || '未知の世界',
        tone: custom_story&.dig('theme') || '冒険的な状況',
        character: custom_story&.dig('character_background'),
        visual_style: custom_story&.dig('visual_style') || '創造的で独創的な雰囲気'
      }
    }

    story = story_settings[story_mode] || story_settings['adventure']

    context = "舞台: #{story[:setting]}, 雰囲気: #{story[:atmosphere]}, トーン: #{story[:tone]}, 視覚的スタイル: #{story[:visual_style]}"
    context += ", キャラクター背景: #{story[:character]}" if story[:character]

    context
  end

  # 物語の展開による感情的な文脈を画像生成に反映
  def enhance_image_context_with_emotions(base_context, story_context)
    return base_context unless story_context

    emotional_analysis = analyze_story_emotions_for_images(story_context)
    return base_context unless emotional_analysis

    "#{base_context}\n\n物語の感情的な展開による視覚的調整:\n#{emotional_analysis}"
  end

  # 物語の展開から感情的な要素を分析（画像生成用）
  def analyze_story_emotions_for_images(story_context)
    return nil unless story_context.is_a?(Hash)

    emotional_elements = []

    # 困難な決断の場面を検出
    if story_context['difficult_decisions'] || story_context['challenges']
      emotional_elements << '困難な決断: 主人公が重要な選択を迫られる場面では、アートにシャープな線とコントラストの強い色彩を追加し、緊張感を視覚的に表現'
    end

    # 悲しい結末を検出
    if story_context['sad_ending'] || story_context['tragic_elements']
      emotional_elements << '悲しい結末: 物語が悲しい結末を迎えた場合、アートの色彩をより深みのあるトーンに調整し、メランコリックな雰囲気を表現'
    end

    # 勝利や成功の場面を検出
    emotional_elements << '勝利の瞬間: 主人公が困難を乗り越えた場面では、アートに光と希望の要素を追加し、明るくエネルギッシュな色彩を使用' if story_context['victory'] || story_context['success']

    # 神秘的な要素を検出
    emotional_elements << '神秘的な要素: 物語に神秘的な要素がある場合、アートに幻想的な色彩と抽象的な形状を追加し、超現実的な雰囲気を表現' if story_context['mystery'] || story_context['magical_elements']

    emotional_elements.join("\n")
  end
end
