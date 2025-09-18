class MbtiController < ApplicationController
  before_action :set_openai_service, only: [:index, :create, :result]

  def index
    @questions = @openai_service.generate_mbti_questions
    session[:questions] = @questions.map do |q|
      {
        question: q.question,
        options: q.options,
        dimension: q.dimension
      }
    end
    session[:answers] = []
    @current_question_index = 0
  end

  def show
    @current_question_index = params[:index].to_i
    @questions = session[:questions] || []
    @answers = session[:answers] || []
    
    if @current_question_index >= @questions.length
      redirect_to mbti_result_path
      return
    end
    
    @current_question = @questions[@current_question_index]
  end

  def create
    @current_question_index = params[:question_index].to_i
    @questions = session[:questions] || []
    @answers = session[:answers] || []
    
    # 回答を保存
    answer = {
      question: @questions[@current_question_index]['question'],
      optionA: @questions[@current_question_index]['options'][0],
      optionB: @questions[@current_question_index]['options'][1],
      choice: params[:choice],
      dimension: @questions[@current_question_index]['dimension']
    }
    
    @answers << answer
    session[:answers] = @answers
    
    # 次の質問へ
    next_index = @current_question_index + 1
    if next_index < @questions.length
      redirect_to mbti_question_path(index: next_index)
    else
      redirect_to mbti_result_path
    end
  end

  def result
    @answers = session[:answers] || []
    @questions = session[:questions] || []
    
    if @answers.empty?
      redirect_to mbti_index_path
      return
    end
    
    # MBTIタイプを計算
    @mbti_result = MbtiResult.calculate_mbti_type(@answers)
    
    # OpenAI APIで追加分析（オプション）
    @ai_analysis = @openai_service.analyze_mbti_responses(@answers) if @mbti_result
    
    # セッションをクリア
    session[:questions] = nil
    session[:answers] = nil
  end

  def restart
    session[:questions] = nil
    session[:answers] = nil
    redirect_to mbti_index_path
  end

  private

  def set_openai_service
    @openai_service = OpenaiService.new
  end
end
