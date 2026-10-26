class QuizController < ApplicationController
  before_action :select_profile
  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    @answers = session.fetch(:quiz_answers, saved_quiz_answers)
    completed = (0...SdgQuiz::QUESTIONS.size).find { |index| !@answers.key?(index.to_s) } || SdgQuiz::QUESTIONS.size
    requested = params[:question].to_s.match?(/\A[0-7]\z/) ? params[:question].to_i : completed
    @index = [ requested, completed ].min
    if params[:question].blank? && @answers.empty?
      render :intro
    elsif @index == SdgQuiz::QUESTIONS.size
      prepare_suggestions
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
    @answers = session.fetch(:quiz_answers, saved_quiz_answers)
    completed = (0...SdgQuiz::QUESTIONS.size).find { |index| !@answers.key?(index.to_s) } || SdgQuiz::QUESTIONS.size
    return redirect_to quiz_path unless params[:question].to_s.match?(/\A[0-7]\z/) && params[:question].to_i <= completed
    @index = params[:question].to_i
    unless %w[0 1 2 3 skip].include?(params[:answer])
      @error = "Choose an answer, or skip this question."
      return render :question, status: :unprocessable_entity
    end
    @answers[@index.to_s] = params[:answer]
    session[:quiz_answers] = @answers
    if onboarding_person?
      current_account.update!(onboarding: current_account.onboarding.merge("quiz_answers" => @answers))
    end
    redirect_to quiz_path(question: @index + 1, profile_id: current_profile&.id), status: :see_other
  end

  def confirm
    @answers = session.fetch(:quiz_answers, saved_quiz_answers)
    return redirect_to quiz_path unless (0...SdgQuiz::QUESTIONS.size).all? { |index| @answers.key?(index.to_s) }
    @selected_targets = params[:target_ids].is_a?(Array) ? params[:target_ids].reject(&:blank?).uniq : []
    if !params[:target_ids].is_a?(Array) || @selected_targets.size > 3 || (@selected_targets - ProfileOptions::TARGETS.keys).any?
      @error = "Choose up to three priorities, or leave them empty if you are still exploring."
      prepare_suggestions
      return render :suggestions, status: :unprocessable_entity
    end
    if onboarding_person?
      current_account.update!(onboarding: current_account.onboarding.merge("quiz_answers" => @answers,
        "target_ids" => @selected_targets, "confirmed" => Time.current.iso8601, "quiz_done" => true))
      redirect_to onboarding_profile_path, status: :see_other
    elsif current_profile
      current_profile.save_quiz!(@answers, targets: @selected_targets)
      redirect_to companies_path(priorities: "1"), notice: "Priorities saved. Explore companies with shared interests.", status: :see_other
    else
      session[:confirmed_quiz_targets] = @selected_targets
      redirect_to companies_path(priorities: "1"), status: :see_other
    end
  end

  private

  def saved_quiz_answers
    onboarding_person? ? current_account.onboarding.fetch("quiz_answers", {}) : (current_profile&.profile&.fetch("quiz_answers", {}) || {})
  end

  def prepare_suggestions
    @matches = SdgQuiz.matches(@answers)
    @selected_targets ||= @matches.keys
  end

  def select_profile
    check_profile_id if current_account
    if session[:quiz_profile_id] != (onboarding_person? ? "onboarding" : current_profile&.id)
      session.delete(:quiz_answers)
      session[:quiz_profile_id] = onboarding_person? ? "onboarding" : current_profile&.id
    end
  end
end
