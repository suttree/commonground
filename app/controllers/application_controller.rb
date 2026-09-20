class ApplicationController < ActionController::Base
  helper_method :current_account, :current_profile

  private

  def current_account
    return unless session[:authenticated_at].to_i > 30.days.ago.to_i
    @current_account ||= Account.find_by(id: session[:account_id])
  end

  def current_profile
    return unless current_account
    @current_profile ||= current_account.submissions.find_by(id: session[:active_profile_id]) || current_account.submissions.order(:id).first
  end

  def require_account
    response.headers["Cache-Control"] = "no-store"
    redirect_to login_path unless current_account
  end
end
