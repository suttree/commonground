class CollaboratorInvitationsController < ApplicationController
  before_action :require_account
  before_action :find_challenge

  def index
    @invitation = @challenge.collaborator_invitations.new
  end

  def create
    @invitation = @challenge.collaborator_invitations.new(params.require(:collaborator_invitation).permit(:email))
    @invitation.expires_at = 14.days.from_now
    current_account.with_lock do
      if CollaboratorInvitation.joins(:challenge).where(challenges: { submission_id: current_account.submissions.select(:id) }).where(created_at: 1.day.ago..).count >= 20
        @invitation.errors.add(:base, "You can send up to 20 invitations a day. Please try again tomorrow.")
      elsif !@challenge.public?
        @invitation.errors.add(:base, "Publish this work and your profile before inviting collaborators.")
      elsif @invitation.email == current_account.email
        @invitation.errors.add(:email, "must belong to someone else")
      else
        @invitation.save
      end
    end
    return render :index, status: :unprocessable_entity unless @invitation.persisted?

    begin
      CollaboratorInvitationMailer.invite(@invitation).deliver_now
      @invitation.update!(sent_at: Time.current)
    rescue StandardError => error
      @invitation.update!(revoked_at: Time.current)
      Rails.logger.error("Invitation delivery failed: #{error.class.name}")
      return redirect_to challenge_collaborator_invitations_path(@challenge), alert: "We couldn't send the invitation. Please try again later.", status: :see_other
    end
    redirect_to challenge_collaborator_invitations_path(@challenge), notice: "Invitation sent.", status: :see_other
  end

  def destroy
    invitation = @challenge.collaborator_invitations.find(params[:id])
    @challenge.with_lock do
      invitation.reload
      invitation.update!(revoked_at: Time.current) unless invitation.accepted_at
    end
    redirect_to challenge_collaborator_invitations_path(@challenge), notice: "Invitation cancelled. Accepted collaborators can be removed by editing the challenge.", status: :see_other
  end

  private

  def find_challenge
    raise ActiveRecord::RecordNotFound unless current_profile
    @challenge = current_account.challenges.find(params[:challenge_id])
  end
end
