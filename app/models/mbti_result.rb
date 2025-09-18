class MbtiResult
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :mbti_type, :string
  attribute :scores, default: {}
  attribute :answers, default: []
  attribute :created_at, :datetime

  validates :mbti_type, presence: true, inclusion: { in: MbtiQuestion::MBTI_TYPES.keys }

  def self.calculate_mbti_type(answers)
    # 各次元のスコアを計算
    scores = {
      'E' => 0, 'I' => 0,
      'S' => 0, 'N' => 0,
      'T' => 0, 'F' => 0,
      'J' => 0, 'P' => 0
    }

    answers.each do |answer|
      dimension = answer[:dimension]
      choice = answer[:choice]
      
      if dimension && choice
        # 選択肢Aを選んだ場合は最初の次元、Bを選んだ場合は2番目の次元にスコアを加算
        if choice == 'A'
          scores[dimension[0]] += 1
        elsif choice == 'B'
          scores[dimension[1]] += 1
        end
      end
    end

    # MBTIタイプを決定
    mbti_type = ''
    mbti_type += scores['E'] > scores['I'] ? 'E' : 'I'
    mbti_type += scores['S'] > scores['N'] ? 'S' : 'N'
    mbti_type += scores['T'] > scores['F'] ? 'T' : 'F'
    mbti_type += scores['J'] > scores['P'] ? 'J' : 'P'

    new(
      mbti_type: mbti_type,
      scores: scores,
      answers: answers,
      created_at: Time.current
    )
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
