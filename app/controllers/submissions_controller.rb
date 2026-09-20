class SubmissionsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, name: "submissions", only: :create, if: -> { !allowed_repeaters.include?(params[:add_section]) },
    with: -> { render plain: "We've received several submissions from this connection. Please try again in ten minutes.", status: :too_many_requests }
  rate_limit to: 40, within: 10.minutes, name: "drafts", only: :create,
    with: -> { render plain: "You've made several draft requests. Please try again in ten minutes.", status: :too_many_requests }

  before_action :require_account, only: [ :edit, :update ]

  def new
    @submission = Submission.new(kind: submission_kind, profile_version: 2)
  end

  def create
    @submission = Submission.new(submission_params.merge(kind: submission_kind, profile_version: 2))
    if @submission.website_confirmation.present?
      redirect_to thanks_path, status: :see_other
      return
    end
    prepare_project_images
    if @image_errors.any?
      @image_errors.each { |message| @submission.errors.add(:projects, message) }
      render :new, status: :unprocessable_entity
    elsif allowed_repeaters.include?(params[:add_section])
      field = allowed_repeaters.find { |name| name == params[:add_section] }
      rows = @submission.profile_entries(field)
      if rows.size < 10
        @submission.profile[field] = rows + [ {} ]
        @expanded_section = field
      else
        @submission.errors.add(field, "must contain no more than 10 entries")
      end
      render :new, status: :ok
    elsif @submission.valid?
      Submission.transaction do
        @draft_images.each_value do |image|
          image.reload
          raise ActiveRecord::RecordNotFound if image.submission_id.present?
        end
        @submission.profile_entries("projects").each { |row| row.delete("image_token"); row.delete("remove_image") }
        @submission.save!
        @draft_images.each_value { |image| image.update!(submission: @submission) }
      end
      session[:pending_submission_id] = @submission.id
      redirect_to create_account_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @submission = params[:profile_id].present? ? current_account.submissions.find(params[:profile_id]) : current_profile
    return redirect_to new_person_path unless @submission
    render :new
  end

  def update
    @submission = params[:profile_id].present? ? current_account.submissions.find(params[:profile_id]) : current_profile
    return head :not_found unless @submission
    existing_projects = @submission.profile_entries("projects").deep_dup
    @submission.assign_attributes(submission_params.except(:email, :consent))
    @submission.published = params.dig(:submission, :published) == "1" if params[:submission].key?(:published)
    @submission.profile_entries("projects").each_with_index do |row, index|
      row["image_id"] = existing_projects.dig(index, "image_id") if existing_projects.dig(index, "image_id")
    end
    prepare_project_images
    if @image_errors.any?
      @image_errors.each { |message| @submission.errors.add(:projects, message) }
      render :new, status: :unprocessable_entity
    elsif allowed_repeaters.include?(params[:add_section])
      field = allowed_repeaters.find { |name| name == params[:add_section] }
      rows = @submission.profile_entries(field)
      @submission.profile[field] = rows + [ {} ] if rows.size < 10
      @expanded_section = field
      render :new
    elsif @submission.valid?
      Submission.transaction do
        @submission.profile_entries("projects").each { |row| row.delete("image_token"); row.delete("remove_image") }
        @submission.save!
        @draft_images.each_value { |image| image.update!(submission: @submission) }
        kept_images = @submission.profile_entries("projects").filter_map { |row| row["image_id"] }
        @submission.portfolio_images.where.not(id: kept_images).destroy_all
      end
      redirect_to dashboard_path(profile_id: @submission.id), notice: "Your profile has been updated.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def prepare_project_images
    @image_errors = []
    @draft_images = {}
    return if @submission.organisation?
    owner = session[:portfolio_upload_key] ||= SecureRandom.hex(24)
    @submission.profile_entries("projects").first(10).each_with_index do |row, index|
      token = row["image_token"]
      image = token.present? ? PortfolioImage.find_signed(token, purpose: "portfolio:#{owner}") : nil
      if token.present? && (image.nil? || image.submission_id.present?)
        @image_errors << "Project #{index + 1}: the image expired or is unavailable. Please choose it again."
        row.delete("image_token")
        next
      end
      upload = params.dig(:project_images, index.to_s)
      if row.delete("remove_image") == "1"
        image&.destroy!
        image = nil
        row.delete("image_token")
        row.delete("image_id")
        row["remove_image"] = "1" if @submission.persisted?
      elsif upload.present?
        replacement = PortfolioImage.stage(upload, owner, replacing: image)
        image&.destroy!
        image = replacement
      end
      if image
        row["image_token"] = image.draft_token
        row["image_id"] = image.id
        @draft_images[index] = image
      end
    rescue ArgumentError => error
      @image_errors << "Project #{index + 1}: #{error.message}"
    end
  end

  def submission_kind
    return @submission.kind if %w[edit update].include?(action_name) && @submission
    request.path.start_with?("/organisations") ? "organisation" : "person"
  end

  def allowed_repeaters
    submission_kind == "organisation" ? %w[products] : %w[skills projects]
  end

  def submission_params
    common = [ :name, :email, :website, :purpose, :consent, :website_confirmation ]
    fields = if submission_kind == "organisation"
      [ :organisation_name, :location, :exploring, :challenge, :mission, :offering, :impact_metrics, :proud_of, :challenge_kind, :help_needed,
        { target_ids: [], sectors_past: [], products: ProfileOptions::REPEATED_FIELDS.fetch("products").keys } ]
    else
      [ :experience, :location, :radius_km, :sector_reason, :education_topics, :satisfaction_feeling, :satisfaction_notes, :exploring,
        { target_ids: [], sectors_past: [], sectors_future: [],
          skills: ProfileOptions::REPEATED_FIELDS.fetch("skills").keys, projects: ProfileOptions::REPEATED_FIELDS.fetch("projects").keys + ProfileOptions::PROJECT_DETAILS.keys + %w[image_token remove_image] } ]
    end
    params.require(:submission).permit(*(common + fields))
  end
end
