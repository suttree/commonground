class ProfilesController < ApplicationController
  before_action :find_profile

  def show
  end

  def skill
    @skills = @profile.profile_entries("skills")
    @position = params[:position].to_i
    @skill = @skills[@position - 1] if @position.positive? && !@profile.organisation?
    raise ActiveRecord::RecordNotFound unless @skill
  end

  private

  def find_profile
    @profile = Submission.published.find_by!(public_slug: params[:slug])
    response.headers["Cache-Control"] = "no-store"
  end
end
