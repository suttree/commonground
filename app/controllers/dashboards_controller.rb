class DashboardsController < ApplicationController
  before_action :require_account
  before_action :check_profile_id

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
