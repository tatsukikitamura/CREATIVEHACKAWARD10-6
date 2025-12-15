# frozen_string_literal: true

# 物語のコンテキストを構築し、フェーズ管理を行うサービス
class StoryContextBuilder
  TOTAL_QUESTIONS = 12

  # 物語フェーズ定義
  PHASES = {
    opening: { range: 1..2, tension: 'low', description: '導入・世界観の提示' },
    rising: { range: 3..5, tension: 'building', description: '問題発生・緊張上昇' },
    climax: { range: 6..8, tension: 'high', description: 'クライマックス・最大の危機' },
    falling: { range: 9..10, tension: 'resolving', description: '解決への道筋' },
    resolution: { range: 11..12, tension: 'conclusion', description: '結末・物語の締めくくり' }
  }.freeze

  # 各フェーズに適した次元の順序（物語の流れに合わせて）
  DIMENSION_SCHEDULE = {
    opening: %w[EI SN],      # 導入：社交性と情報収集の傾向
    rising: %w[TF JP SN],    # 上昇：問題への判断と対処
    climax: %w[EI TF JP],    # クライマックス：協力と重要な決断
    falling: %w[SN JP TF],   # 下降：解決策の模索
    resolution: %w[TF EI]    # 結末：最終決断と他者との関係
  }.freeze

  def initialize(session)
    @session = session
    @progress = session.story_progress # 回答済み数
    @answers = session.answers_array
  end

  # 次の質問番号（1から開始）
  def next_question_number
    @progress + 1
  end

  # 現在のフェーズを判定
  def current_phase
    question_num = next_question_number
    PHASES.find { |_, v| v[:range].include?(question_num) }&.first || :opening
  end

  # フェーズ情報を取得
  def phase_info
    PHASES[current_phase]
  end

  # フェーズに適した次元を選択（ランダムではなく戦略的に）
  def recommended_dimension
    phase = current_phase
    candidates = DIMENSION_SCHEDULE[phase]
    used_in_phase = dimensions_used_in_current_phase

    # まだ使っていない次元を優先、なければランダム
    unused = candidates - used_in_phase
    unused.any? ? unused.first : candidates.sample
  end

  # 累積コンテキスト（過去の選択の要約）を構築
  def cumulative_context
    return nil if @answers.empty?

    # 直近3問の詳細 + それ以前の要約
    recent_count = 3
    recent = @answers.last(recent_count)
    older = @answers.length > recent_count ? @answers[0...-recent_count] : []

    parts = []

    # 過去の選択傾向（4問以上ある場合）
    parts << "【これまでの傾向】#{summarize_choices(older)}" if older.any?

    # 直近の展開（詳細）
    if recent.any?
      parts << '【直近の展開】'
      start_index = @answers.length - recent.length
      recent.each_with_index do |a, i|
        chosen = a[:choice] == 'A' ? a[:optionA] : a[:optionB]
        parts << "  #{start_index + i + 1}問目: #{a[:question]}"
        parts << "  → 選択: 「#{chosen}」"
      end
    end

    parts.join("\n")
  end

  # ストーリーアーク指示（フェーズに応じた物語の方向性）
  def story_arc_instruction
    case current_phase
    when :opening
      <<~ARC
        【フェーズ：導入】(#{next_question_number}/#{TOTAL_QUESTIONS}問目)
        物語の世界観を提示し、主人公の状況を確立する段階。
        落ち着いたペースで世界観への没入を促す。
      ARC
    when :rising
      <<~ARC
        【フェーズ：上昇】(#{next_question_number}/#{TOTAL_QUESTIONS}問目)
        問題が発生し、緊張感が高まる段階。
        選択の結果が影響を与え始め、状況が複雑化していく。
      ARC
    when :climax
      <<~ARC
        【フェーズ：クライマックス】(#{next_question_number}/#{TOTAL_QUESTIONS}問目)
        最大の危機。これまでの選択の結果が集約される重要な場面。
        緊迫感を最大限に高め、重要な決断を迫る。
      ARC
    when :falling
      <<~ARC
        【フェーズ：下降】(#{next_question_number}/#{TOTAL_QUESTIONS}問目)
        解決への道筋が見え始める段階。
        希望と困難が交錯し、結末に向かって動き出す。
      ARC
    when :resolution
      <<~ARC
        【フェーズ：結末】(#{next_question_number}/#{TOTAL_QUESTIONS}問目)
        物語の締めくくり。選択の結果として結末が決まる感覚を与える。
        これまでの旅を振り返りながら、最後の選択を提示する。
      ARC
    end
  end

  # フェーズ固有の指示（質問生成用）
  def phase_specific_instruction
    case current_phase
    when :opening
      '世界観を伝えつつ、物語への没入を促す穏やかな展開'
    when :rising
      '問題が深刻化し、選択に緊張感を持たせる。前回の選択の影響を見せる'
    when :climax
      '最大の危機。これまでの選択が集約される重要な場面。劇的な展開'
    when :falling
      '解決への道筋が見える。希望と困難が交錯する'
    when :resolution
      '物語の締めくくり。選択によって結末が決まる感覚を与える'
    end
  end

  # 物語の雰囲気レベル（緊張度）
  def tension_level
    phase_info[:tension]
  end

  private

  # 現在のフェーズで使用した次元を取得
  def dimensions_used_in_current_phase
    phase_range = phase_info[:range]
    @answers
      .each_with_index
      .select { |_, i| phase_range.include?(i + 1) }
      .map { |a, _| a[:dimension] }
      .compact
      .uniq
  end

  # 選択傾向を要約
  def summarize_choices(answers)
    return '選択なし' if answers.empty?

    # 各次元での傾向を要約
    dimension_tendencies = answers.group_by { |a| a[:dimension] }

    summaries = dimension_tendencies.map do |dim, ans|
      next nil if dim.nil?

      a_count = ans.count { |a| a[:choice] == 'A' }
      b_count = ans.length - a_count

      dim_info = OpenaiPrompts.dimension_info[dim]
      next nil unless dim_info

      if a_count > b_count
        "#{dim_info[:desc_a]}傾向"
      elsif b_count > a_count
        "#{dim_info[:desc_b]}傾向"
      else
        "#{dim}:バランス型"
      end
    end.compact

    summaries.any? ? summaries.join('、') : '傾向未確定'
  end
end
