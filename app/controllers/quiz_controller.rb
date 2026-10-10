class QuizController < ApplicationController
  before_action :select_profile
  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    @answers = session.fetch(:quiz_answers, current_profile&.profile&.fetch("quiz_answers", {}) || {})
    completed = (0...SdgQuiz::QUESTIONS.size).find { |index| !@answers.key?(index.to_s) } || SdgQuiz::QUESTIONS.size
    requested = params[:question].to_s.match?(/\A[0-7]\z/) ? params[:question].to_i : completed
    @index = [ requested, completed ].min
    if @index == SdgQuiz::QUESTIONS.size
      @matches = SdgQuiz.matches(@answers)
      render :suggestions
    else
      render :question
    end
  end

  def create
    if params[:restart] == "1"
      session[:quiz_answers] = {}
      return redirect_to quiz_path(profile_id: current_profile&.id), status: :see_other
    end
    @answers = session.fetch(:quiz_answers, current_profile&.profile&.fetch("quiz_answers", {}) || {})
    completed = (0...SdgQuiz::QUESTIONS.size).find { |index| !@answers.key?(index.to_s) } || SdgQuiz::QUESTIONS.size
    return redirect_to quiz_path unless params[:question].to_s.match?(/\A[0-7]\z/) && params[:question].to_i <= completed
    @index = params[:question].to_i
    unless %w[0 1 2 3 skip].include?(params[:answer])
      @error = "Choose an answer, or skip this question."
      return render :question, status: :unprocessable_entity
    end
    @answers[@index.to_s] = params[:answer]
    session[:quiz_answers] = @answers
    if current_profile && (0...SdgQuiz::QUESTIONS.size).all? { |index| @answers.key?(index.to_s) }
      current_profile.save_quiz!(@answers)
    end
    redirect_to quiz_path(question: @index + 1, profile_id: current_profile&.id), status: :see_other
  end

  private

  def select_profile
    check_profile_id if current_account
    if session[:quiz_profile_id] != current_profile&.id
      session.delete(:quiz_answers)
      session[:quiz_profile_id] = current_profile&.id
    end
  end

end
