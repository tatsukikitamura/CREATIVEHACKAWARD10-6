# frozen_string_literal: true

module OpenaiFallbacks
  module_function

  def generate_fallback_single_question(dimension)
    fallback_questions = {
      'EI' => [
        { question: '新しい人との出会いについてどう感じますか？', optionA: '多くの人と会うのが楽しい', optionB: '少数の親しい人との時間を好む' },
        { question: 'エネルギーをどこから得ますか？', optionA: '人との交流や活動から', optionB: '一人の時間や内省から' },
        { question: '会議やグループ活動についてどう感じますか？', optionA: '活発に参加して意見を述べる', optionB: '聞き役に回ることが多い' }
      ],
      'SN' => [
        { question: '情報を処理する際、どちらを重視しますか？', optionA: '具体的な事実と詳細', optionB: '全体的なパターンと可能性' },
        { question: '学習する際、どちらを好みますか？', optionA: '段階的で体系的な方法', optionB: '全体的な理解から始める方法' },
        { question: '新しいアイデアについてどう感じますか？', optionA: '実用的で実現可能なものを好む', optionB: '革新的で創造的なものを好む' }
      ],
      'TF' => [
        { question: '決定を下す際、何を重視しますか？', optionA: '論理的な分析と客観性', optionB: '価値観と人間関係への影響' },
        { question: '問題解決の際、どちらを重視しますか？', optionA: '客観的な事実と論理', optionB: '人の感情や価値観' },
        { question: '他人を評価する際、何を重視しますか？', optionA: '能力と成果', optionB: '努力と動機' }
      ],
      'JP' => [
        { question: '日常生活でどちらを好みますか？', optionA: '計画を立てて計画的に進める', optionB: '柔軟性を保って臨機応変に対応' },
        { question: '締切についてどう感じますか？', optionA: '締切を守るのは重要', optionB: '締切は柔軟に扱える' },
        { question: '旅行の計画についてどう感じますか？', optionA: '詳細な計画を立てる', optionB: '大まかな計画で自由に行動' }
      ]
    }

    questions = fallback_questions[dimension] || fallback_questions['EI']
    question_data = questions.sample

    MbtiQuestion.new(
      question: question_data[:question],
      options: [question_data[:optionA], question_data[:optionB]],
      dimension: dimension
    )
  end

  def generate_fallback_questions
    [
      MbtiQuestion.new(
        question: '新しい人との出会いについてどう感じますか？',
        options: %w[多くの人と会うのが楽しい 少数の親しい人との時間を好む],
        dimension: 'EI'
      ),
      MbtiQuestion.new(
        question: '情報を処理する際、どちらを重視しますか？',
        options: %w[具体的な事実と詳細 全体的なパターンと可能性],
        dimension: 'SN'
      ),
      MbtiQuestion.new(
        question: '決定を下す際、何を重視しますか？',
        options: %w[論理的な分析と客観性 価値観と人間関係への影響],
        dimension: 'TF'
      ),
      MbtiQuestion.new(
        question: '日常生活でどちらを好みますか？',
        options: %w[計画を立てて計画的に進める 柔軟性を保って臨機応変に対応],
        dimension: 'JP'
      ),
      MbtiQuestion.new(
        question: 'エネルギーをどこから得ますか？',
        options: %w[人との交流や活動から 一人の時間や内省から],
        dimension: 'EI'
      ),
      MbtiQuestion.new(
        question: '学習する際、どちらを好みますか？',
        options: %w[段階的で体系的な方法 全体的な理解から始める方法],
        dimension: 'SN'
      ),
      MbtiQuestion.new(
        question: '問題解決の際、どちらを重視しますか？',
        options: %w[客観的な事実と論理 人の感情や価値観],
        dimension: 'TF'
      ),
      MbtiQuestion.new(
        question: '締切についてどう感じますか？',
        options: %w[締切を守るのは重要 締切は柔軟に扱える],
        dimension: 'JP'
      ),
      MbtiQuestion.new(
        question: '会議やグループ活動についてどう感じますか？',
        options: %w[活発に参加して意見を述べる 聞き役に回ることが多い],
        dimension: 'EI'
      ),
      MbtiQuestion.new(
        question: '新しいアイデアについてどう感じますか？',
        options: %w[実用的で実現可能なものを好む 革新的で創造的なものを好む],
        dimension: 'SN'
      ),
      MbtiQuestion.new(
        question: '他人を評価する際、何を重視しますか？',
        options: %w[能力と成果 努力と動機],
        dimension: 'TF'
      ),
      MbtiQuestion.new(
        question: '旅行の計画についてどう感じますか？',
        options: %w[詳細な計画を立てる 大まかな計画で自由に行動],
        dimension: 'JP'
      )
    ]
  end
end


