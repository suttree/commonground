class QuizController < ApplicationController
  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    @answers = session.fetch(:quiz_answers, {})
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
      session.delete(:quiz_answers)
      return redirect_to quiz_path, status: :see_other
    end
    @answers = session.fetch(:quiz_answers, {})
    completed = (0...SdgQuiz::QUESTIONS.size).find { |index| !@answers.key?(index.to_s) } || SdgQuiz::QUESTIONS.size
    return redirect_to quiz_path unless params[:question].to_s.match?(/\A[0-7]\z/) && params[:question].to_i <= completed
    @index = params[:question].to_i
    unless %w[0 1 2 3 skip].include?(params[:answer])
      @error = "Choose an answer, or skip this question."
      return render :question, status: :unprocessable_entity
    end
    @answers[@index.to_s] = params[:answer]
    session[:quiz_answers] = @answers
    redirect_to quiz_path(question: @index + 1), status: :see_other
  end

  def explore
    @goal_ids = []
    @target_ids = []
    render :topics
  end

  def select
    @goal_ids = choices(:goals)
    @target_ids = choices(:targets)
    if params[:step] == "topics"
      render :topics
    elsif @goal_ids.empty? || @goal_ids.size > 3 || (@goal_ids - ProfileOptions::GOALS.pluck("id")).any?
      @error = "Choose between one and three topics to continue."
      render :topics, status: :unprocessable_entity
    elsif params[:step] == "results"
      if @target_ids.empty? || @target_ids.size > 3 || (@target_ids - SdgQuiz.target_ids(@goal_ids)).any?
        @error = "Choose between one and three priorities from your topics."
        render :targets, status: :unprocessable_entity
      else
        render :results
      end
    else
      @target_ids &= SdgQuiz.target_ids(@goal_ids)
      render :targets
    end
  end

  private

  def choices(key)
    value = params[key]
    value.is_a?(Array) ? value.select { |item| item.is_a?(String) }.reject(&:blank?).uniq : []
  end
end
