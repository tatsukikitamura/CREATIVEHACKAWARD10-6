class MbtiQuestion
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :question, :string
  attribute :options, default: []
  attribute :category, :string
  attribute :dimension, :string

  # MBTIの4つの次元
  DIMENSIONS = {
    'E' => '外向性 (Extraversion)',
    'I' => '内向性 (Introversion)',
    'S' => '感覚 (Sensing)',
    'N' => '直感 (Intuition)',
    'T' => '思考 (Thinking)',
    'F' => '感情 (Feeling)',
    'J' => '判断 (Judging)',
    'P' => '知覚 (Perceiving)'
  }.freeze

  # MBTIタイプの説明
  MBTI_TYPES = {
    'INTJ' => '建築家 - 戦略的思考と計画性を持つ',
    'INTP' => '論理学者 - 革新的な思想家',
    'ENTJ' => '指揮官 - 大胆で想像力豊かなリーダー',
    'ENTP' => '討論者 - 賢く好奇心旺盛な思想家',
    'INFJ' => '提唱者 - 静かで神秘的な理想主義者',
    'INFP' => '仲介者 - 詩的で親切な利他主義者',
    'ENFJ' => '主人公 - カリスマ的で人を鼓舞するリーダー',
    'ENFP' => '運動家 - 熱意があり創造的で社交的',
    'ISTJ' => '管理者 - 実用的で事実重視',
    'ISFJ' => '擁護者 - 非常に献身的で温かい擁護者',
    'ESTJ' => '幹部 - 優秀な管理者',
    'ESFJ' => '領事 - 非常に思いやりがあり社交的',
    'ISTP' => '巨匠 - 大胆で実用的な実験者',
    'ISFP' => '冒険家 - 柔軟で魅力的な芸術家',
    'ESTP' => '起業家 - 賢くエネルギッシュで非常に知覚力のある人',
    'ESFP' => 'エンターテイナー - 自発的でエネルギッシュで熱心な人'
  }.freeze

  def self.generate_questions
    # OpenAI APIを使って質問を生成するためのプロンプト
    prompt = <<~PROMPT
      MBTI（Myers-Briggs Type Indicator）の性格診断テスト用の質問を生成してください。
      以下の4つの次元について、それぞれ3つずつ、合計12個の質問を作成してください：
      
      1. 外向性(E) vs 内向性(I)
      2. 感覚(S) vs 直感(N)  
      3. 思考(T) vs 感情(F)
      4. 判断(J) vs 知覚(P)
      
      各質問は以下の形式で出力してください：
      - 質問文
      - 選択肢A（最初の次元を表す）
      - 選択肢B（2番目の次元を表す）
      - 次元（E/I, S/N, T/F, J/Pのいずれか）
      
      JSON形式で出力してください。
    PROMPT

    prompt
  end
end
