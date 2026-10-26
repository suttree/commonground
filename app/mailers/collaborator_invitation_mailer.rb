class CollaboratorInvitationMailer < ApplicationMailer
  def invite(invitation)
    prepare(invitation)
    mail(to: invitation.email, from: ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>"), subject: "Have you collaborated on #{@challenge.title}?")
  end

  def reminder(invitation)
    prepare(invitation)
    mail(to: invitation.email, from: ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>"), subject: "Your engagement in #{@challenge.title} matters")
  end

  private

  def prepare(invitation)
    @invitation = invitation
    @challenge = invitation.challenge
    @owner = @challenge.submission.display_name
    @url = invitation_url(token: invitation.token)
  end
end
