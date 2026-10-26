class OnboardingController < ApplicationController
  include ProfilePhotoUpload
  before_action :require_account, except: :new
  before_action :prepare_onboarding, except: :new
  before_action { response.headers["Cache-Control"] = "no-store" }

  def new
    redirect_to new_person_path if current_account
  end

  def profile
    @submission = build_profile
  end

  def skip_quiz
    current_account.update!(onboarding: current_account.onboarding.merge("quiz_done" => true))
    redirect_to onboarding_profile_path, status: :see_other
  end

  def create_profile
    @submission = build_profile
    @submission.assign_attributes(params.require(:submission).permit(:name, :location, :purpose, :experience, :skills_summary, :consent))
    prepare_profile_photo
    if @profile_photo_error
      @submission.errors.add(:profile_photo, @profile_photo_error)
      return render :profile, status: :unprocessable_entity
    end
    if @submission.valid?
      Submission.transaction do
        @submission.save!
        persist_profile_photo
      end
      current_account.update!(onboarding: {})
      session.delete(:onboarding_person)
      session.delete(:quiz_answers)
      session[:active_profile_id] = @submission.id
      invited = session[:collaborator_invitation_token].present?
      destination = invited ? invitation_path(token: session[:collaborator_invitation_token]) : companies_path(priorities: "1")
      message = invited ? "Your profile is ready. Accept the invitation below to join the project." : "Your profile is ready. Find companies working on what matters to you."
      redirect_to destination, notice: message, status: :see_other
    else
      render :profile, status: :unprocessable_entity
    end
  end

  private

  def prepare_onboarding
    if (profile = current_account.submissions.find_by(kind: "person"))
      session[:active_profile_id] = profile.id
      return redirect_to edit_account_profile_path
    end
    session[:onboarding_person] = true
  end

  def build_profile
    draft = current_account.onboarding
    profile = current_account.submissions.new(kind: "person", profile_version: 2, email: current_account.email, name: draft["name"],
      target_ids: draft.fetch("target_ids", []), exploring: Array(draft["target_ids"]).empty? ? "1" : "0")
    if draft["confirmed"]
      profile.profile["quiz_answers"] = draft.fetch("quiz_answers", {})
      profile.profile["quiz_completed_at"] = draft["confirmed"]
    end
    profile
  end
end
