class AiPhotoService
  def initialize
    @openai_service = OpenaiService.new
  end

  # MBTIタイプと回答に基づいて画像のプロンプトを生成
  def generate_image_prompts(mbti_type, answers)
    begin
      prompt = build_image_prompt(mbti_type, answers)
      response = @openai_service.client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            {
              role: "system",
              content: "あなたは画像生成の専門家です。MBTIタイプと回答に基づいて、その人の性格を表現する画像のプロンプトを生成してください。"
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
      return parse_image_response(content) if content

      generate_fallback_images(mbti_type)
    rescue => e
      Rails.logger.error "Image prompt generation error: #{e.message}"
      generate_fallback_images(mbti_type)
    end
  end

  # DALL-Eを使用して画像を生成
  def generate_image_with_dalle(prompt, size = "1024x1024")
    begin
      Rails.logger.info "Generating image with prompt: #{prompt}"
      
      response = @openai_service.client.images.generate(
        parameters: {
          prompt: prompt,
          size: size,
          n: 1
        }
      )

      image_url = response.dig("data", 0, "url")
      if image_url
        Rails.logger.info "Image generated successfully: #{image_url}"
        return image_url
      else
        Rails.logger.warn "No image URL in response: #{response}"
        return nil
      end
    rescue => e
      Rails.logger.error "DALL-E image generation error: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
      nil
    end
  end

  # 複数の画像を生成
  def generate_multiple_images(mbti_type, answers)
    prompts = generate_image_prompts(mbti_type, answers)
    images = []

    prompts[:prompts].each do |prompt_data|
      image_url = generate_image_with_dalle(prompt_data[:prompt])
      if image_url
        images << {
          url: image_url,
          title: prompt_data[:title],
          description: prompt_data[:description]
        }
      end
    end

    images
  end

  # MBTIタイプに基づくデフォルト画像プロンプト
  def get_default_prompts_for_type(mbti_type)
    type_prompts = {
      'INTJ' => [
        "Strategic thinker in a modern office, focused and analytical, dark blue tones",
        "Mountain peak at sunrise, representing vision and determination",
        "Person reading complex charts and graphs, surrounded by books"
      ],
      'INTP' => [
        "Abstract geometric patterns, representing logical thinking, purple and blue",
        "Library with ancient books and modern technology, mysterious atmosphere",
        "Person working on complex puzzle or code, deep in thought"
      ],
      'ENTJ' => [
        "Leader addressing a crowd, confident and commanding, red and gold tones",
        "City skyline at sunset, representing ambition and success",
        "Person in business suit making important decisions"
      ],
      'ENTP' => [
        "Colorful brainstorming session, creative and energetic, bright colors",
        "Innovative cityscape with futuristic buildings, dynamic and creative",
        "Person presenting new ideas with enthusiasm and energy"
      ],
      'INFJ' => [
        "Gentle light through trees, representing insight and wisdom, soft green tones",
        "Peaceful garden with flowing water, serene and contemplative",
        "Person helping others, compassionate and understanding"
      ],
      'INFP' => [
        "Dreamy watercolor painting, artistic and emotional, pastel colors",
        "Magical forest with soft lighting, imaginative and whimsical",
        "Person creating art or writing, expressing inner feelings"
      ],
      'ENFJ' => [
        "Warm community gathering, people connecting and supporting each other",
        "Sunrise over a community, representing hope and inspiration",
        "Person teaching or mentoring others, caring and encouraging"
      ],
      'ENFP' => [
        "Explosion of colors and creativity, energetic and spontaneous",
        "Adventure scene with multiple paths, exciting and open",
        "Person exploring new places with excitement and curiosity"
      ],
      'ISTJ' => [
        "Organized workspace with everything in perfect order, reliable and structured",
        "Stable mountain landscape, solid and dependable",
        "Person methodically completing tasks with precision"
      ],
      'ISFJ' => [
        "Cozy home environment, caring and nurturing, warm earth tones",
        "Gentle garden with blooming flowers, peaceful and supportive",
        "Person taking care of others with love and attention"
      ],
      'ESTJ' => [
        "Efficient office environment, organized and productive, professional tones",
        "Well-planned city with clear structure, reliable and systematic",
        "Person leading a team meeting with authority and competence"
      ],
      'ESFJ' => [
        "Happy family gathering, social and caring, warm and inviting",
        "Community celebration, joyful and supportive atmosphere",
        "Person organizing events and bringing people together"
      ],
      'ISTP' => [
        "Technical workshop with tools and machinery, practical and hands-on",
        "Adventure sports scene, independent and action-oriented",
        "Person fixing or building something with skill and focus"
      ],
      'ISFP' => [
        "Artistic studio with creative works, sensitive and aesthetic",
        "Natural landscape with artistic elements, peaceful and beautiful",
        "Person creating something beautiful with care and attention"
      ],
      'ESTP' => [
        "Dynamic action scene, energetic and spontaneous, bold colors",
        "Adventure sports or outdoor activities, exciting and active",
        "Person taking immediate action with confidence and energy"
      ],
      'ESFP' => [
        "Vibrant party or celebration, fun-loving and social, bright colors",
        "Festive outdoor scene, joyful and energetic",
        "Person entertaining others with enthusiasm and charm"
      ]
    }

    prompts = type_prompts[mbti_type] || type_prompts['INTJ']
    
    {
      prompts: [
        {
          title: "抽象的な表現",
          description: "あなたの性格を抽象的に表現",
          prompt: prompts[0]
        },
        {
          title: "自然・風景での表現", 
          description: "あなたの性格を自然で表現",
          prompt: prompts[1]
        },
        {
          title: "日常シーンでの表現",
          description: "あなたの性格を日常で表現",
          prompt: prompts[2]
        }
      ]
    }
  end

  private

  def build_image_prompt(mbti_type, answers)
    answer_summary = answers.map { |a| "#{a[:dimension]}: #{a[:choice]}" }.join(", ")
    
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
    PROMPT
  end

  def parse_image_response(content)
    lines = content.split("\n")
    prompts = []
    current_prompt = nil
    current_title = nil
    current_description = nil
    
    lines.each do |line|
      if line.start_with?("##")
        if current_prompt && current_title
          prompts << {
            title: current_title,
            description: current_description,
            prompt: current_prompt.strip
          }
        end
        
        current_title = line.gsub(/^##\s*/, "")
        current_description = ""
        current_prompt = ""
      elsif line.strip.present? && !line.start_with?("#")
        if current_prompt.nil?
          current_prompt = line
        else
          current_prompt += " " + line
        end
      end
    end
    
    # 最後のプロンプトを追加
    if current_prompt && current_title
      prompts << {
        title: current_title,
        description: current_description,
        prompt: current_prompt.strip
      }
    end
    
    { prompts: prompts }
  end

  def generate_fallback_images(mbti_type)
    {
      prompts: [
        {
          title: "抽象的な表現",
          description: "あなたの性格を抽象的に表現",
          prompt: "Abstract art representing #{mbti_type} personality type, vibrant colors, modern style"
        },
        {
          title: "自然・風景での表現",
          description: "あなたの性格を自然で表現",
          prompt: "Beautiful landscape representing #{mbti_type} personality, peaceful and inspiring"
        },
        {
          title: "日常シーンでの表現",
          description: "あなたの性格を日常で表現",
          prompt: "Daily life scene representing #{mbti_type} personality, warm and inviting"
        }
      ]
    }
  end

end
