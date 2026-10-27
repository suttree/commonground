class SubmissionsController < ApplicationController
  include ProfilePhotoUpload
  rate_limit to: 10, within: 10.minutes, name: "submissions", only: :create, if: -> { !allowed_repeaters.include?(params[:add_section]) },
    with: -> { render plain: "We've received several submissions from this connection. Please try again in ten minutes.", status: :too_many_requests }
  rate_limit to: 40, within: 10.minutes, name: "drafts", only: :create,
    with: -> { render plain: "You've made several draft requests. Please try again in ten minutes.", status: :too_many_requests }

  before_action :require_account, only: [ :edit, :update ]

  before_action :redirect_existing_profile, only: [ :new, :create ]
  before_action :check_profile_id, only: [ :edit, :update ]

  def new
    if submission_kind == "person"
      if current_account
        session[:onboarding_person] = true
        current_account.update!(onboarding: { "name" => "" }) if current_account.onboarding.empty?
        return redirect_to(current_account.onboarding["quiz_done"] ? onboarding_profile_path : quiz_path)
      end
      return render "onboarding/new"
    end
    @submission = Submission.new(kind: submission_kind, profile_version: 2, email: current_account&.email)
  end

  def create
    @submission = Submission.new(submission_params.merge(kind: submission_kind, profile_version: 2))
    if current_account
      @submission.account = current_account
      @submission.email = current_account.email
    elsif Account.joins(:submission).exists?(email: @submission.email)
      return redirect_to login_path, notice: "Log in to edit your existing profile.", status: :see_other
    end
    if @submission.website_confirmation.present?
      redirect_to thanks_path, status: :see_other
      return
    end
    prepare_project_images
    prepare_profile_photo
    if @image_errors.any? || @profile_photo_error
      @image_errors.each { |message| @submission.errors.add(:projects, message) }
      @submission.errors.add(:profile_photo, @profile_photo_error) if @profile_photo_error
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
        persist_profile_photo
      end
      if current_account
        session[:active_profile_id] = @submission.id
        redirect_to session[:collaborator_invitation_token].present? ? invitation_path(token: session[:collaborator_invitation_token]) : dashboard_path, status: :see_other
      else
        session[:pending_submission_id] = @submission.id
        redirect_to create_account_path, status: :see_other
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @submission = current_profile
    return redirect_to new_person_path unless @submission
    prepare_edit_section
    render :edit
  end

  def update
    @submission = current_profile
    return head :not_found unless @submission
    prepare_edit_section if params[:section].present?
    @unsaved_section = true if @section
    attributes = submission_params.except(:email, :consent)
    attributes = attributes.slice(*@sections.fetch(@section).last) if @section
    existing_projects = @submission.profile_entries("projects").deep_dup
    @submission.assign_attributes(attributes)
    @submission.profile_entries("projects").each_with_index do |row, index|
      row["image_id"] = existing_projects.dig(index, "image_id") if existing_projects.dig(index, "image_id")
    end
    @image_errors, @draft_images = [], {}
    prepare_project_images if !@section || @section == "portfolio"
    prepare_profile_photo if !@section || @section == "basics"
    if @image_errors.any? || @profile_photo_error
      @image_errors.each { |message| @submission.errors.add(:projects, message) }
      @submission.errors.add(:profile_photo, @profile_photo_error) if @profile_photo_error
      render(@section ? :edit : :new, status: :unprocessable_entity)
    elsif allowed_repeaters.include?(params[:add_section]) && (!@section || @sections.fetch(@section).last.include?(params[:add_section]))
      field = allowed_repeaters.find { |name| name == params[:add_section] }
      rows = @submission.profile_entries(field)
      @submission.profile[field] = rows + [ {} ] if rows.size < 10
      @expanded_section = field
      render(@section ? :edit : :new)
    elsif @submission.valid?
      Submission.transaction do
        @submission.profile_entries("projects").each { |row| row.delete("image_token"); row.delete("remove_image") }
        @submission.save!
        @draft_images.each_value { |image| image.update!(submission: @submission) }
        persist_profile_photo
        if !@section || @section == "portfolio"
          kept_images = @submission.profile_entries("projects").filter_map { |row| row["image_id"] }
          @submission.portfolio_images.where(side_project_id: nil).where.not(id: kept_images).destroy_all
        end
      end
      destination = @section ? edit_account_profile_path(section: @section, profile_id: @submission.id) : dashboard_path
      message = @section ? "#{@sections.fetch(@section).first} saved." : "Your profile has been updated."
      redirect_to destination, notice: message, status: :see_other
    else
      render(@section ? :edit : :new, status: :unprocessable_entity)
    end
  end

  private

  def prepare_edit_section
    @sections = ProfileSections.for(@submission)
    @section = params[:section].presence || "basics"
    raise ActiveRecord::RecordNotFound unless @sections.key?(@section)
  end

  def redirect_existing_profile
    return unless submission_kind == "person" && current_account
    personal_profile = current_account.submissions.find_by(kind: "person")
    if personal_profile
      session[:active_profile_id] = personal_profile.id
      redirect_to edit_account_profile_path, notice: "You already have a personal profile. You can edit it here.", status: :see_other
    end
  end

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
    request.path_parameters[:kind] || "person"
  end

  def allowed_repeaters
    submission_kind == "organisation" ? %w[products] : %w[skills projects]
  end

  def submission_params
    common = [ :name, :email, :website, :purpose, :consent, :website_confirmation, :contact_action, :contact_destination ]
    fields = if submission_kind == "organisation"
      [ :organisation_name, :location, :exploring, :challenge, :mission, :offering, :impact_metrics, :proud_of, :challenge_kind, :help_needed,
        { target_ids: [], sectors_past: [], products: ProfileOptions::REPEATED_FIELDS.fetch("products").keys } ]
    else
      [ :experience, :skills_summary, :location, :radius_km, :sector_reason, :education_topics, :satisfaction_feeling, :satisfaction_notes, :exploring,
        { target_ids: [], sectors_past: [], sectors_future: [],
          skills: ProfileOptions::REPEATED_FIELDS.fetch("skills").keys, projects: ProfileOptions::REPEATED_FIELDS.fetch("projects").keys + ProfileOptions::PROJECT_DETAILS.keys + %w[image_token remove_image] } ]
    end
    params.require(:submission).permit(*(common + fields))
  end
end
