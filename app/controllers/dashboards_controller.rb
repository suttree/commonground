class DashboardsController < ApplicationController
  before_action :require_account
  before_action :check_profile_id

  def switch_profile
    profile = current_account.submissions.find(params[:selected_profile_id])
    session.delete(:onboarding_person)
    session[:active_profile_id] = profile.id
    session.delete(:quiz_answers)
    session.delete(:quiz_profile_id)
    redirect_to dashboard_path, status: :see_other
  end

  def show
    @profile = current_profile
    if @profile
      @active_challenge = @profile.challenges.find_by(status: "active")
      @past_challenges = @profile.challenges.where.not(status: "active").order(updated_at: :desc)
      goals = Array(@profile.target_ids).map { |id| id.split(".").first }.uniq
      recommendations = Challenge.discoverable.where(status: "active").where.not(submission_id: @profile.id)
      if goals.any?
        conditions = goals.map { "EXISTS (SELECT 1 FROM json_each(challenges.target_ids) WHERE value LIKE ?)" }.join(" OR ")
        recommendations = recommendations.where(conditions, *goals.map { |id| "#{id}.%" })
      end
      @recommended_challenges = recommendations.includes(:submission).recent.limit(3)
    end
  end
end
