class ApplicationController < ActionController::Base
  helper_method :current_account, :current_profile, :owns_profile?

  private

  def current_account
    return unless session[:authenticated_at].to_i > 30.days.ago.to_i
    @current_account ||= Account.find_by(id: session[:account_id])
  end

  def current_profile
    return unless current_account
    @current_profile ||= current_account.submissions.find_by(id: session[:active_profile_id]) || current_account.submission
  end

  def owns_profile?(profile)
    current_account.present? && profile.account_id == current_account.id
  end

  def check_profile_id
    if params[:profile_id].present? && params[:profile_id].to_s != current_profile&.id.to_s
      raise ActiveRecord::RecordNotFound
    end
  end

  def require_account
    response.headers["Cache-Control"] = "no-store"
    redirect_to login_path unless current_account
  end
end
