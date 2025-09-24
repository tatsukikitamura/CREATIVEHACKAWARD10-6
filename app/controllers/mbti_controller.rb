class MbtiController < ApplicationController
  before_action :set_mbti_session, except: [:index, :select_mode, :set_mode, :result]
  protect_from_forgery with: :exception
  # 二問目以降でCSRF検証が失敗する事象に対応するため、回答系のみ除外
  skip_forgery_protection only: [:answer, :back]
  
  def index
    # 新しいセッションIDを生成
    @session_id = SecureRandom.uuid
  end

  def select_mode
    @session_id = params[:session_id]
    @modes = MbtiSession::STORY_MODES
  end

  def set_mode
    # セッションを作成または取得
    @mbti_session = MbtiSession.find_or_create_by_session_id(params[:session_id])
    
    if params[:story_mode].present?
      @mbti_session.update!(story_mode: params[:story_mode])
      redirect_to mbti_show_path(session_id: @mbti_session.session_id)
    else
      flash[:alert] = "モードを選択してください。"
      redirect_to mbti_select_mode_path(session_id: params[:session_id])
    end
  end

  def show
    # モードが設定されていない場合はモード選択画面にリダイレクト
    if @mbti_session.story_mode.blank?
      redirect_to mbti_select_mode_path(session_id: @mbti_session.session_id)
      return
    end
    
    # 完了したセッションの場合は結果画面にリダイレクト
    if @mbti_session.completed?
      redirect_to mbti_result_path(session_id: @mbti_session.session_id)
      return
    end
    
    # 現在の質問を生成または取得
    @current_question = @mbti_session.current_question
    
    if @current_question.nil?
      # 新しい質問を生成
      @current_question = generate_next_question
      if @current_question.nil?
        redirect_to mbti_result_path(session_id: @mbti_session.session_id)
        return
      end
    end

    @current_question_number = @mbti_session.current_question_number
    @can_terminate_early = @mbti_session.can_terminate_early?
    
    # 質問の次元に基づいてUIテーマを決定
    @ui_theme = determine_ui_theme(@current_question.dimension)
  end

  def answer
    if params[:choice].present?
      # 回答を保存
      current_question = @mbti_session.current_question
      dimension = current_question.dimension || @mbti_session.random_dimension
      
      Rails.logger.info "Answer processing - Question dimension: #{current_question.dimension}"
      Rails.logger.info "Answer processing - Fallback dimension: #{@mbti_session.random_dimension}"
      Rails.logger.info "Answer processing - Final dimension: #{dimension}"
      
      answer = {
        question: current_question.question,
        choice: params[:choice],
        optionA: current_question.options[0],
        optionB: current_question.options[1],
        dimension: dimension
      }
      
      Rails.logger.info "Answer data to be saved: #{answer.inspect}"
      
      @mbti_session.add_answer(@mbti_session.current_question_index, answer)

      # 次の質問に進む（制限なし）
      redirect_to mbti_show_path(session_id: @mbti_session.session_id)
    elsif params[:terminate_early].present?
      # 途中終了
      if @mbti_session.can_terminate_early?
        @mbti_session.complete!
        redirect_to mbti_result_path(session_id: @mbti_session.session_id)
      else
        flash[:alert] = "最低3問は回答してください。"
        redirect_to mbti_show_path(session_id: @mbti_session.session_id)
      end
    else
      flash[:alert] = "選択肢を選んでください。"
      redirect_to mbti_show_path(session_id: @mbti_session.session_id)
    end
  end

  def back
    # 一つ前に戻す
    prev_index = [@mbti_session.current_question_index - 1, 0].max
    if prev_index < @mbti_session.current_question_index
      # 回答を消さずにインデックスのみ戻す（ユーザーが再選択可能）
      @mbti_session.update!(current_question_index: prev_index)
    end
    redirect_to mbti_show_path(session_id: @mbti_session.session_id), status: :see_other
  end

  def result
    # セッションIDからセッションを取得
    session_id = params[:session_id] || session[:mbti_session_id]
    
    if session_id.blank?
      redirect_to mbti_path
      return
    end
    
    @mbti_session = MbtiSession.find_by(session_id: session_id)
    
    if @mbti_session.nil? || !@mbti_session.completed?
      redirect_to mbti_path
      return
    end
    
    @answers = @mbti_session.answers_array
    
    if @answers.empty?
      redirect_to mbti_path
      return
    end

    # 回答数を取得
    @answer_count = @answers.length
    
    # MBTIタイプを計算
    @result = MbtiResult.calculate_mbti_type(@answers)
    
    # セッションは保持（再開可能にする）
    # @mbti_session.destroy
  end

  def analyze
    session_id = params[:session_id] || session[:mbti_session_id]
    return render json: { error: 'invalid_session' }, status: :unprocessable_entity if session_id.blank?

    mbti_session = MbtiSession.find_by(session_id: session_id)
    return render json: { error: 'not_found' }, status: :not_found if mbti_session.nil?
    return render json: { error: 'not_completed' }, status: :unprocessable_entity unless mbti_session.completed?

    answers = mbti_session.answers_array
    result = MbtiResult.calculate_mbti_type(answers)
    mbti_type = params[:type].presence || result.mbti_type

    openai_service = OpenaiService.new
    analysis = openai_service.generate_detailed_analysis(answers, mbti_type)

    if analysis.nil?
      return render json: { error: 'analysis_unavailable' }, status: :service_unavailable
    end

    render json: { mbti_type: mbti_type, type_details: analysis[:type_details], answer_summary: analysis[:answer_summary] }
  end

  def resume
    # セッションIDからセッションを取得
    session_id = params[:session_id]
    
    if session_id.blank?
      redirect_to mbti_path
      return
    end
    
    @mbti_session = MbtiSession.find_by(session_id: session_id)
    
    if @mbti_session.nil?
      redirect_to mbti_path
      return
    end
    
    # 完了状態を解除して再開可能にする
    @mbti_session.update!(completed: false)
    
    redirect_to mbti_show_path(session_id: @mbti_session.session_id)
  end

  private

  def determine_ui_theme(dimension)
    case dimension
    when 'EI'
      # 外向性/内向性 - 活発 vs 静か
      'dynamic'
    when 'SN'
      # 感覚/直感 - 現実的 vs 抽象的
      'analytical'
    when 'TF'
      # 思考/感情 - 論理的 vs 感情的
      'emotional'
    when 'JP'
      # 判断/知覚 - 構造的 vs 柔軟
      'structured'
    else
      'default'
    end
  end

  def set_mbti_session
    session_id = params[:session_id] || session[:mbti_session_id]
    
    if session_id.blank?
      redirect_to mbti_path
      return
    end
    
    @mbti_session = MbtiSession.find_or_create_by_session_id(session_id)
    session[:mbti_session_id] = session_id
  end

  def generate_next_question
    openai_service = OpenaiService.new
    dimension = @mbti_session.random_dimension
    question_number = @mbti_session.current_question_number
    story_mode = @mbti_session.story_mode
    last_answer = @mbti_session.last_answer
    story_progress = @mbti_session.story_progress
    
    Rails.logger.info "Generating story question for dimension: #{dimension}, question: #{question_number}, mode: #{story_mode}, progress: #{story_progress}"
    Rails.logger.info "Last answer: #{last_answer.inspect}"
    
    question = openai_service.generate_continuing_story_mbti_question(
      dimension, 
      question_number, 
      story_mode, 
      last_answer, 
      story_progress
    )
    
    if question
      # 質問をセッションに追加
      questions = @mbti_session.questions || []
      questions << question.attributes
      @mbti_session.update!(questions: questions)
      Rails.logger.info "Successfully added question to session"
    end
    
    question
  end

  def generate_questions
    openai_service = OpenaiService.new
    questions = openai_service.generate_mbti_questions
    
    # 質問が生成されなかった場合はフォールバックを使用
    if questions.nil? || questions.empty?
      questions = openai_service.send(:generate_fallback_questions)
    end
    
    questions
  end
end
