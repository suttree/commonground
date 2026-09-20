class DashboardsController < ApplicationController
  before_action :require_account

  def show
    @profiles = current_account.submissions.order(:id)
    @profile = params[:profile_id].present? ? @profiles.find(params[:profile_id]) : @profiles.first
    session.delete(:quiz_answers) if session[:active_profile_id] != @profile&.id
    session[:active_profile_id] = @profile&.id
  end
end
