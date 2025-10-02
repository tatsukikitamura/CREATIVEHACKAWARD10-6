# frozen_string_literal: true

# AIを使用してMBTIタイプに基づいた画像生成を行うサービス
class AiPhotoService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて画像のプロンプトを生成
  def generate_image_prompts(mbti_type, answers)
    prompt = build_image_prompt(mbti_type, answers)
    response = @openai_service.client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
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
        max_tokens: 800,
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

  # 画像を生成（gpt-image-1 を優先、失敗時にリトライとフォールバック）
  def generate_image_with_dalle(prompt, size = '1024x1024')
    Rails.logger.info "Generating image with prompt: #{prompt}"

    # 過度に長いプロンプトはAPI側でエラーになりやすいのでトリミング
    safe_prompt = prompt.to_s.strip
    safe_prompt = safe_prompt[0, 1800] if safe_prompt.length > 1800

    models = ['gpt-image-1', 'dall-e-2']
    last_error = nil

    models.each do |model|
      2.times do |attempt|
        begin
          sleep(0.5 * (2**attempt)) if attempt.positive? # エクスポネンシャルバックオフ

          response = @openai_service.client.images.generate(
            parameters: {
              model: model,
              prompt: safe_prompt,
              size: size,
              n: 1,
              quality: model == 'gpt-image-1' ? 'low' : nil
            }.compact
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
          Rails.logger.error "Image generation error on #{model}: #{e.message}"
          break
        end
      end
    end

    Rails.logger.error "Image generation failed after retries: #{last_error&.message}"
    nil
  end

  # 複数の画像を生成
  def generate_multiple_images(mbti_type, answers)
    prompts = generate_image_prompts(mbti_type, answers)
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

  def build_image_prompt(mbti_type, answers)
    answer_summary = answers.map { |a| "#{a[:dimension]}: #{a[:choice]}" }.join(', ')

    <<~PROMPT
      MBTIタイプ: #{mbti_type}
      回答内容: #{answer_summary}

      この人の性格特性を表現する3つの異なる画像のプロンプトを生成してください：

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
end
