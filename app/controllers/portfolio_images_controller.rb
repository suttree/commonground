class PortfolioImagesController < ApplicationController
  def show
    profiles = Submission.published
    profiles = profiles.or(Submission.where(account_id: current_account.id)) if current_account
    image = PortfolioImage.where(submission_id: profiles.select(:id)).find(params[:id])
    deliver(image)
  end

  def draft
    image = PortfolioImage.find_signed(params[:token], purpose: "portfolio:#{session[:portfolio_upload_key]}")
    raise ActiveRecord::RecordNotFound if image.nil? || image.submission_id.present?
    deliver(image)
  end

  private

  def deliver(image)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data image.data, type: image.content_type, disposition: "inline"
  end
end
