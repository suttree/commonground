class MemberMailer < ApplicationMailer
  default from: -> { ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>") }

  def welcome(email)
    mail(to: email, subject: "Welcome to Commonbound!")
  end

  def contacted(contact_request)
    @request = contact_request
    @intent = ContactRequest::OPTIONS.fetch(contact_request.intent)[:label]
    @project = contact_request.challenge
    mail(to: member_email(contact_request.submission), bcc: ENV["CONTACT_BCC"].presence, reply_to: contact_request.email,
      subject: "Someone’s commonbounding you!")
  end

  def added_to_project(challenge, member)
    @challenge = challenge
    @owner = challenge.submission.display_name
    @url = challenge_url(challenge)
    mail(to: member_email(member), subject: "Have you collaborated on #{challenge.title}?")
  end

  def invitation_accepted(invitation, member)
    @challenge = invitation.challenge
    @member = member
    @url = profile_url(member.public_slug)
    mail(to: member_email(@challenge.submission), subject: "Yes, #{member.display_name} is in!")
  end

  private

  def member_email(submission)
    submission.account&.email || submission.email
  end
end
