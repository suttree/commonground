class InvitationsController < ApplicationController
  before_action :find_invitation

  def show
    session[:collaborator_invitation_token] = params[:token] if @invitation.available?
  end

  def update
    unless current_account
      session[:collaborator_invitation_token] = params[:token]
      return redirect_to login_path, notice: "Sign in with the email address that received this invitation."
    end
    if @invitation.accept!(current_account)
      session.delete(:collaborator_invitation_token)
      redirect_to challenge_path(@invitation.challenge), notice: "You are now listed as a collaborator.", status: :see_other
    else
      redirect_to invitation_path(token: params[:token]), alert: "This invitation cannot be accepted. Check the account and profile requirements below.", status: :see_other
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to invitation_path(token: params[:token]), alert: "We couldn't add your profile. The owner may need to make room in the collaborator list.", status: :see_other
  end

  private

  def find_invitation
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
    @invitation = CollaboratorInvitation.find_by_token(params[:token])
    unless @invitation
      render plain: "This invitation link is invalid or has expired. Ask the owner for a new invitation.", status: :not_found
    end
  end
end
