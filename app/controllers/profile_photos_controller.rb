class ProfilePhotosController < ApplicationController
  def show
    profiles = Submission.published
    profiles = profiles.or(Submission.where(account_id: current_account.id)) if current_account
    deliver(ProfilePhoto.where(submission_id: profiles.select(:id)).find(params[:id]))
  end

  def draft
    photo = ProfilePhoto.find_signed(params[:token], purpose: "profile-photo:#{session[:profile_photo_upload_key]}")
    raise ActiveRecord::RecordNotFound if photo.nil? || photo.submission_id.present?
    deliver(photo)
  end

  private

  def deliver(photo)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data photo.data, type: photo.content_type, disposition: "inline"
  end
end
