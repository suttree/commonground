class QuizController < ApplicationController
  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    @goal_ids = []
    @target_ids = []
    render :topics
  end

  def create
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
