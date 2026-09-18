class SubmissionsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :create, if: -> { !allowed_repeaters.include?(params[:add_section]) },
    with: -> { render plain: "We've received several submissions from this connection. Please try again in ten minutes.", status: :too_many_requests }

  def new
    @submission = Submission.new(kind: submission_kind, profile_version: 2)
  end

  def create
    @submission = Submission.new(submission_params.merge(kind: submission_kind, profile_version: 2))
    if @submission.website_confirmation.present?
      redirect_to thanks_path, status: :see_other
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
    elsif @submission.save
      redirect_to thanks_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def submission_kind
    request.path.start_with?("/organisations") ? "organisation" : "person"
  end

  def allowed_repeaters
    submission_kind == "organisation" ? %w[products] : %w[skills projects]
  end

  def submission_params
    common = [ :name, :email, :website, :purpose, :consent, :website_confirmation ]
    fields = if submission_kind == "organisation"
      [ :organisation_name, :challenge, :mission, :offering, :impact_metrics, :proud_of, :challenge_kind, :help_needed,
        { products: ProfileOptions::REPEATED_FIELDS.fetch("products").keys } ]
    else
      [ :experience, :location, :radius_km, :sector_reason, :education_topics, :satisfaction_feeling, :satisfaction_notes,
        { target_ids: [], sectors_past: [], sectors_future: [],
          skills: ProfileOptions::REPEATED_FIELDS.fetch("skills").keys, projects: ProfileOptions::REPEATED_FIELDS.fetch("projects").keys } ]
    end
    params.require(:submission).permit(*(common + fields))
  end
end
