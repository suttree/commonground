module ProfilePhotoUpload
  extend ActiveSupport::Concern

  private

  def prepare_profile_photo
    return if @submission.organisation?

    owner = session[:profile_photo_upload_key] ||= SecureRandom.hex(24)
    token = params[:profile_photo_token]
    @draft_profile_photo = ProfilePhoto.find_signed(token, purpose: "profile-photo:#{owner}") if token.present?
    if token.present? && (@draft_profile_photo.nil? || @draft_profile_photo.submission_id.present?)
      @draft_profile_photo = nil
      @profile_photo_error = "The photo expired or is unavailable. Please choose it again."
      return
    end

    @remove_profile_photo = params[:remove_profile_photo] == "1"
    if @remove_profile_photo
      @draft_profile_photo&.destroy!
      @draft_profile_photo = nil
    elsif params[:profile_photo].present?
      replacement = ProfilePhoto.stage(params[:profile_photo], owner, replacing: @draft_profile_photo)
      @draft_profile_photo&.destroy!
      @draft_profile_photo = replacement
    end
  rescue ArgumentError => error
    @profile_photo_error = error.message
  end

  # Call inside the transaction that saves the profile.
  def persist_profile_photo
    return unless @draft_profile_photo || @remove_profile_photo

    if @draft_profile_photo
      @draft_profile_photo.reload
      raise ActiveRecord::RecordNotFound if @draft_profile_photo.submission_id.present?
    end
    @submission.profile_photo&.destroy!
    @draft_profile_photo&.update!(submission: @submission)
  end
end
