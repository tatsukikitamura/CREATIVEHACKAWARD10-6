class MbtiResult
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :mbti_type, :string
  attribute :scores, default: {}
  attribute :answers, default: []
  attribute :created_at, :datetime

  validates :mbti_type, presence: true, inclusion: { in: MbtiQuestion::MBTI_TYPES.keys }

  def self.calculate_mbti_type(answers)
    # 回答データの検証
    if answers.nil? || !answers.is_a?(Array) || answers.empty?
      Rails.logger.error "Invalid answers data: #{answers.inspect}"
      return new(
        mbti_type: 'INTJ', # デフォルト値
        scores: { 'E' => 0, 'I' => 0, 'S' => 0, 'N' => 0, 'T' => 0, 'F' => 0, 'J' => 0, 'P' => 0 },
        answers: answers || [],
        created_at: Time.current
      )
    end

    # 各次元のスコアを計算
    scores = {
      'E' => 0, 'I' => 0,
      'S' => 0, 'N' => 0,
      'T' => 0, 'F' => 0,
      'J' => 0, 'P' => 0
    }

    answers.each do |answer|
      # 文字列キーとシンボルキーの両方に対応
      dimension = answer[:dimension] || answer['dimension']
      choice = answer[:choice] || answer['choice']
      
      Rails.logger.info "Processing answer: dimension=#{dimension}, choice=#{choice}"
      Rails.logger.info "Full answer data: #{answer.inspect}"
      
      if dimension && choice
        # dimensionが2文字の文字列であることを確認
        if dimension.is_a?(String) && dimension.length == 2
          # 選択肢Aを選んだ場合は最初の次元、Bを選んだ場合は2番目の次元にスコアを加算
          if choice == 'A'
            first_dimension = dimension[0]
            if scores.key?(first_dimension)
              scores[first_dimension] += 1
              Rails.logger.info "Added 1 to #{first_dimension}, new score: #{scores[first_dimension]}"
            else
              Rails.logger.error "Invalid dimension character: #{first_dimension}"
            end
          elsif choice == 'B'
            second_dimension = dimension[1]
            if scores.key?(second_dimension)
              scores[second_dimension] += 1
              Rails.logger.info "Added 1 to #{second_dimension}, new score: #{scores[second_dimension]}"
            else
              Rails.logger.error "Invalid dimension character: #{second_dimension}"
            end
          end
        elsif dimension.is_a?(String) && dimension.length == 1
          # 1文字の次元の場合の処理（既存の無効なデータ対応）
          Rails.logger.warn "Single character dimension detected: #{dimension}, attempting to map to valid dimension"
          
          # 1文字の次元を2文字のペアにマッピング
          dimension_mapping = {
            'E' => 'EI', 'I' => 'EI',
            'S' => 'SN', 'N' => 'SN', 
            'T' => 'TF', 'F' => 'TF',
            'J' => 'JP', 'P' => 'JP'
          }
          
          mapped_dimension = dimension_mapping[dimension]
          if mapped_dimension
            Rails.logger.info "Mapped #{dimension} to #{mapped_dimension}"
            if choice == 'A'
              first_dimension = mapped_dimension[0]
              if scores.key?(first_dimension)
                scores[first_dimension] += 1
                Rails.logger.info "Added 1 to #{first_dimension}, new score: #{scores[first_dimension]}"
              end
            elsif choice == 'B'
              second_dimension = mapped_dimension[1]
              if scores.key?(second_dimension)
                scores[second_dimension] += 1
                Rails.logger.info "Added 1 to #{second_dimension}, new score: #{scores[second_dimension]}"
              end
            end
          else
            Rails.logger.error "Cannot map single character dimension: #{dimension}"
          end
        else
          Rails.logger.error "Invalid dimension format: #{dimension} (expected 1 or 2-character string)"
        end
      else
        Rails.logger.warn "Invalid answer data: #{answer.inspect}"
      end
    end

    Rails.logger.info "Final scores: #{scores.inspect}"
    
    # MBTIタイプを決定
    begin
      mbti_type = ''
      mbti_type += scores['E'] > scores['I'] ? 'E' : 'I'
      mbti_type += scores['S'] > scores['N'] ? 'S' : 'N'
      mbti_type += scores['T'] > scores['F'] ? 'T' : 'F'
      mbti_type += scores['J'] > scores['P'] ? 'J' : 'P'

      # 生成されたタイプが有効かチェック
      unless MbtiQuestion::MBTI_TYPES.key?(mbti_type)
        Rails.logger.error "Invalid MBTI type generated: #{mbti_type}"
        mbti_type = 'INTJ' # フォールバック
      end

      Rails.logger.info "Calculated MBTI type: #{mbti_type}"

      new(
        mbti_type: mbti_type,
        scores: scores,
        answers: answers,
        created_at: Time.current
      )
    rescue => e
      Rails.logger.error "Error calculating MBTI type: #{e.message}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join("\n")}"
      
      # エラー時のフォールバック
      new(
        mbti_type: 'INTJ',
        scores: scores,
        answers: answers,
        created_at: Time.current
      )
    end
  end

  def description
    MbtiQuestion::MBTI_TYPES[mbti_type]
  end

  def dimension_scores
    {
      '外向性/内向性' => { 'E' => scores['E'], 'I' => scores['I'] },
      '感覚/直感' => { 'S' => scores['S'], 'N' => scores['N'] },
      '思考/感情' => { 'T' => scores['T'], 'F' => scores['F'] },
      '判断/知覚' => { 'J' => scores['J'], 'P' => scores['P'] }
    }
  end
end

