class CollaboratorInvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @challenge = invitation.challenge
    @url = invitation_url(token: invitation.token)
    mail(to: invitation.email, from: ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>"), subject: "An invitation to collaborate on Commonbound")
  end
end
