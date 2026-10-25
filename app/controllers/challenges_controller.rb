class ChallengesController < ApplicationController
  before_action -> { require_account_for_search(%i[q location industry goal status]) }, only: :index
  before_action :require_account, except: [ :index, :show ]
  before_action :require_profile, except: [ :index, :show ]
  before_action :find_owned_challenge, only: [ :edit, :update ]

  def index
    return unless current_account

    @filters = %i[q location industry goal status].to_h { |key| [ key, params[key].to_s.strip.first(200) ] }
    @filters[:status] = "" unless %w[active completed].include?(@filters[:status])
    records = Challenge.discoverable.filtered(@filters)
    @count = records.count
    @page = [ params[:page].to_i, 1 ].max
    @challenges = records.includes(:submission, :organisation).recent.limit(24).offset((@page - 1) * 24)
  end

  def show
    @challenge = Challenge.includes(:submission, :organisation).find(params[:id])
    raise ActiveRecord::RecordNotFound unless @challenge.public? || owns_profile?(@challenge.submission)
    response.headers["Cache-Control"] = "no-store"
  end

  def new
    profile = params[:submission_id].present? ? current_account.submissions.find(params[:submission_id]) : current_profile
    @challenge = profile.challenges.new(location: profile.location, target_ids: Array(profile.target_ids).first(3))
    prepare_form
  end

  def create
    profile_id = params.dig(:challenge, :submission_id)
    profile = profile_id.present? ? current_account.submissions.find(profile_id) : current_profile
    @challenge = profile.challenges.new(challenge_params)
    save_challenge
  end

  def edit
    prepare_form
  end

  def update
    profile_id = params.dig(:challenge, :submission_id)
    @challenge.submission = current_account.submissions.find(profile_id) if profile_id.present?
    @challenge.assign_attributes(challenge_params)
    save_challenge
  end

  private

  def require_profile
    redirect_to new_person_path, notice: "Create your profile before starting a project." unless current_profile
  end

  def find_owned_challenge
    @challenge = current_account.challenges.find(params[:id])
  end

  def prepare_form
    @organisations = Submission.published.where(kind: "organisation").order(:organisation_name)
    @owned_profiles = current_account.submissions.order(:kind, :organisation_name, :name)
    existing_ids = Array(@challenge.collaborator_ids_in_database)
    @members = Submission.published.or(Submission.where(id: existing_ids)).where.not(id: @challenge.submission_id).order(:name)
    @active_challenge = @challenge.submission.challenges.find_by(status: "active")
  end

  def save_challenge
    if @challenge.save
      redirect_to challenge_path(@challenge), notice: @challenge.completed? ? "Your completed project is now in your portfolio." : "Your project has been saved.", status: :see_other
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @challenge.errors.add(:status, "cannot be active while another project is active. Update its status first.")
    prepare_form
    render :edit, status: :unprocessable_entity
  end

  def challenge_params
    params.require(:challenge).permit(:title, :organisation_id, :organisation_name, :industry, :location, :description, :objectives,
      :target, :status, :project_role, :context, :approach, :results, :project_url, help_options: [], target_ids: [], collaborator_ids: [])
  end
end
