class ProfilesController < ApplicationController
  before_action :find_profile

  def show
    @profile_challenges = @profile.challenges.publicly_visible.recent
    @current_challenge = @profile_challenges.find_by(status: "active")
    @completed_challenges = @profile_challenges.where(status: "completed")
    @archived_challenges = @profile_challenges.where(status: %w[paused abandoned])
  end

  def skill
    @skills = @profile.profile_entries("skills")
    @position = params[:position].to_i
    @skill = @skills[@position - 1] if @position.positive? && !@profile.organisation?
    raise ActiveRecord::RecordNotFound unless @skill
  end

  def project
    @projects = @profile.profile_entries("projects")
    @position = params[:position].to_i
    @project = @projects[@position - 1] if @position.positive? && !@profile.organisation?
    raise ActiveRecord::RecordNotFound unless @project
  end

  private

  def find_profile
    profiles = Submission.published
    profiles = profiles.or(Submission.where(account_id: current_account.id)) if current_account
    @profile = profiles.find_by!(public_slug: params[:slug])
    response.headers["Cache-Control"] = "no-store"
  end
end
