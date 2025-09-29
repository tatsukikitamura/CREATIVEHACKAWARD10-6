class MbtiController < ApplicationController
  before_action :set_mbti_session, except: [:index, :mode_selection, :select_mode, :set_mode, :make_mode, :create_story, :result, :game_master, :game_master_answer, :game_master_ending]
  protect_from_forgery with: :exception
  # 二問目以降でCSRF検証が失敗する事象に対応するため、回答系のみ除外
  skip_forgery_protection only: [:answer, :back, :game_master_answer]
  
  def index
    # 新しいセッションIDを生成
    @session_id = SecureRandom.uuid
  end

  def mode_selection
    @session_id = params[:session_id]
  end

  def select_mode
    @session_id = params[:session_id]
    @modes = MbtiSession::STORY_MODES
    @engine = params[:engine]
  end

  def set_mode
    # セッションを作成または取得
    @mbti_session = MbtiSession.find_or_create_by_session_id(params[:session_id])
    
    if params[:story_mode].present?
      if params[:story_mode] == 'creator'
        redirect_to mbti_make_mode_path(session_id: @mbti_session.session_id)
      else
        # engine=gamemaster の場合はゲームマスターエンジンで開始
        if params[:engine] == 'gamemaster'
          @mbti_session.update!(story_mode: params[:story_mode])
          redirect_to mbti_game_master_path(session_id: @mbti_session.session_id)
        else
          @mbti_session.update!(story_mode: params[:story_mode])
          redirect_to mbti_show_path(session_id: @mbti_session.session_id)
        end
      end
    else
      flash[:alert] = "モードを選択してください。"
      redirect_to mbti_select_mode_path(session_id: params[:session_id])
    end
  end

  def make_mode
    @session_id = params[:session_id]
  end

  def create_story
    @mbti_session = MbtiSession.find_or_create_by_session_id(params[:session_id])
    
    # カスタム物語の設定を保存
    custom_story = {
      setting: params[:setting],
      theme: params[:theme],
      mood: params[:mood],
      character_background: params[:character_background]
    }
    
    # クリエイターモード開始時に進行をリセット
    @mbti_session.update!(
      story_mode: 'creator',
      custom_story: custom_story,
      questions: [],
      answers: [],
      current_question_index: 0,
      completed: false
    )
    
    redirect_to mbti_show_path(session_id: @mbti_session.session_id)
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

  def result_ai
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
    
    # AI診断の詳細分析を生成
    #openai_service = OpenaiService.new
    #@ai_analysis = openai_service.generate_detailed_analysis(@answers, @result.mbti_type)
    
    # 音楽と画像はボタンが押されたときに生成されるため、ここでは生成しない
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

  def personalized_report
    session_id = params[:session_id] || session[:mbti_session_id]
    return render json: { error: 'invalid_session' }, status: :unprocessable_entity if session_id.blank?

    mbti_session = MbtiSession.find_by(session_id: session_id)
    return render json: { error: 'not_found' }, status: :not_found if mbti_session.nil?
    return render json: { error: 'not_completed' }, status: :unprocessable_entity unless mbti_session.completed?

    answers = mbti_session.answers_array
    result = MbtiResult.calculate_mbti_type(answers)
    mbti_type = params[:type].presence || result.mbti_type
    story_mode = mbti_session.story_mode || 'adventure'

    openai_service = OpenaiService.new
    story_report = openai_service.generate_personalized_story_report(answers, mbti_type, story_mode)

    if story_report.nil?
      return render json: { error: 'report_unavailable' }, status: :service_unavailable
    end

    render json: { 
      mbti_type: mbti_type, 
      story_mode: story_mode,
      story_analysis: story_report[:story_analysis], 
      personality_insights: story_report[:personality_insights],
      growth_suggestions: story_report[:growth_suggestions]
    }
  end

  def generate_image
    prompt = params[:prompt]
    return render json: { error: 'prompt_required' }, status: :bad_request if prompt.blank?

    # プロンプトの前後の引用符を削除
    prompt = prompt.gsub(/^["']|["']$/, '').strip

    ai_photo_service = AiPhotoService.new
    image_url = ai_photo_service.generate_image_with_dalle(prompt)

    if image_url
      render json: { image_url: image_url }
    else
      render json: { error: 'image_generation_failed' }, status: :service_unavailable
    end
  end

  def generate_music
    session_id = params[:session_id] || session[:mbti_session_id]
    return render json: { error: 'invalid_session' }, status: :unprocessable_entity if session_id.blank?

    mbti_session = MbtiSession.find_by(session_id: session_id)
    return render json: { error: 'not_found' }, status: :not_found if mbti_session.nil?
    return render json: { error: 'not_completed' }, status: :unprocessable_entity unless mbti_session.completed?

    answers = mbti_session.answers_array
    result = MbtiResult.calculate_mbti_type(answers)

    # AI音楽サービスで音楽提案を生成（物語の設定も含める）
    ai_music_service = AiMusicService.new
    music_recommendations = ai_music_service.generate_music_recommendations(
      result.mbti_type, 
      answers, 
      mbti_session.story_mode, 
      mbti_session.custom_story
    )
    playlist_info = ai_music_service.generate_playlist_info(
      result.mbti_type, 
      answers, 
      mbti_session.story_mode, 
      mbti_session.custom_story
    )

    render json: { 
      music_recommendations: music_recommendations,
      playlist_info: playlist_info
    }
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

  # AIゲームマスター方式のアクション
  def game_master
    # セッションIDを取得または新規作成
    session_id = params[:session_id] || session[:mbti_session_id]
    
    if session_id.blank?
      # 新しいセッションを作成
      @mbti_session = MbtiSession.create!(
        session_id: SecureRandom.uuid,
        story_mode: params[:story_mode] || 'adventure',
        completed: false,
        story_state: {}
      )
      session[:mbti_session_id] = @mbti_session.session_id
    else
      @mbti_session = MbtiSession.find_by(session_id: session_id)
      if @mbti_session.nil?
        redirect_to mbti_path
        return
      end
    end

    # AIゲームマスターサービスを使用して場面を生成
    ai_gm_service = AiGameMasterService.new
    scene_data = ai_gm_service.generate_story_scene(@mbti_session.story_state, @mbti_session.story_mode)
    
    # セッションに場面データを保存
    @mbti_session.update!(
      story_state: @mbti_session.story_state.merge(
        'current_scene' => scene_data,
        'inventory' => (@mbti_session.story_state['inventory'] || []) + (scene_data[:inventory_updates] || []),
        'flags' => (@mbti_session.story_state['flags'] || {}).merge(scene_data[:flag_updates] || {})
      )
    )

    @scene_text = scene_data[:scene_text]
    @question_dimension = scene_data[:question_dimension]
    @choices = scene_data[:choices]
    @progress = @mbti_session.story_state['progress'] || 0
    @goal = @mbti_session.story_state['goal']
    @inventory = @mbti_session.story_state['inventory'] || []
  end

  def game_master_answer
    session_id = params[:session_id] || session[:mbti_session_id]
    return redirect_to mbti_path if session_id.blank?

    @mbti_session = MbtiSession.find_by(session_id: session_id)
    return redirect_to mbti_path if @mbti_session.nil?

    choice_value = params[:choice_value]
    progress_impact = params[:progress_impact]&.to_i || 5

    # AIゲームマスターサービスで選択を処理
    ai_gm_service = AiGameMasterService.new
    current_story_state = @mbti_session.story_state || {}
    updated_story_state = ai_gm_service.process_player_choice(
      current_story_state, 
      choice_value, 
      progress_impact
    )

    # セッションを更新
    @mbti_session.update!(story_state: updated_story_state)

    # エンディングに到達したかチェック
    progress = updated_story_state['progress'] || 0
    if progress >= 100
      redirect_to mbti_game_master_ending_path(session_id: session_id)
    else
      redirect_to mbti_game_master_path(session_id: session_id)
    end
  end

  def game_master_ending
    session_id = params[:session_id] || session[:mbti_session_id]
    return redirect_to mbti_path if session_id.blank?

    @mbti_session = MbtiSession.find_by(session_id: session_id)
    return redirect_to mbti_path if @mbti_session.nil?

    # AIゲームマスターサービスでエンディングを生成
    ai_gm_service = AiGameMasterService.new
    ending_data = ai_gm_service.generate_ending(@mbti_session.story_state)

    # 回答履歴からMBTIタイプを計算
    answers = @mbti_session.story_state['history']&.map do |choice|
      {
        dimension: @mbti_session.story_state['current_scene']['question_dimension'],
        choice: choice.include?('外向') ? 'A' : choice.include?('内向') ? 'B' : 
                choice.include?('感覚') ? 'A' : choice.include?('直感') ? 'B' :
                choice.include?('思考') ? 'A' : choice.include?('感情') ? 'B' :
                choice.include?('計画') ? 'A' : choice.include?('柔軟') ? 'B' : 'A'
      }
    end || []

    @result = MbtiResult.calculate_mbti_type(answers)
    @ending_text = ending_data[:ending_text]
    @mbti_analysis = ending_data[:mbti_analysis]
    @personality_insights = ending_data[:personality_insights]
    @achievement = ending_data[:achievement]
    @story_state = @mbti_session.story_state

    # セッションを完了状態にする
    @mbti_session.update!(completed: true)
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
      story_progress,
      @mbti_session.custom_story
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
