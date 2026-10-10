class ChallengesController < ApplicationController
  before_action :require_account, except: [ :index, :show ]
  before_action :require_profile, except: [ :index, :show ]
  before_action :find_owned_challenge, only: [ :edit, :update ]

  def index
    @filters = %i[q location industry goal status].to_h { |key| [ key, params[key].to_s.strip.first(200) ] }
    @filters[:status] = "" unless %w[active completed].include?(@filters[:status])
    records = Challenge.discoverable.filtered(@filters)
    @count = records.count
    @page = [ params[:page].to_i, 1 ].max
    @challenges = records.includes(:submission).recent.limit(24).offset((@page - 1) * 24)
  end

  def show
    @challenge = Challenge.includes(:submission).find(params[:id])
    raise ActiveRecord::RecordNotFound unless @challenge.public? || @challenge.submission == current_profile
    response.headers["Cache-Control"] = "no-store"
  end

  def new
    @challenge = current_profile.challenges.new(location: current_profile.location,
      organisation_name: current_profile.organisation? ? current_profile.organisation_name : nil,
      target_ids: Array(current_profile.target_ids).first(3))
    prepare_form
  end

  def create
    @challenge = current_profile.challenges.new(challenge_params)
    save_challenge
  end

  def edit
    prepare_form
  end

  def update
    @challenge.assign_attributes(challenge_params)
    save_challenge
  end

  private

  def require_profile
    redirect_to new_person_path, notice: "Create your profile before adding a challenge." unless current_profile
  end

  def find_owned_challenge
    @challenge = current_profile.challenges.find(params[:id])
  end

  def prepare_form
    @members = Submission.published.where.not(id: current_profile.id).order(:name)
    @active_challenge = current_profile.challenges.find_by(status: "active")
  end

  def save_challenge
    if @challenge.save
      redirect_to challenge_path(@challenge), notice: @challenge.completed? ? "Your completed project is now in your portfolio." : "Your challenge has been saved.", status: :see_other
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @challenge.errors.add(:status, "cannot be active while another challenge is active. Update its status first.")
    prepare_form
    render :edit, status: :unprocessable_entity
  end

  def challenge_params
    params.require(:challenge).permit(:title, :organisation_name, :industry, :location, :description, :objectives,
      :target, :status, :project_role, :context, :approach, :results, :project_url, help_options: [], target_ids: [], collaborator_ids: [])
  end
end
