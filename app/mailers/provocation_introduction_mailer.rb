class ProvocationIntroductionMailer < ApplicationMailer
  default from: -> { ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>") }

  def requested(request)
    @request = request
    return unless request.available?
    @profile = request.requester_profile
    mail(to: request.recipient.email, subject: "Someone would like an introduction")
  end

  def accepted(request)
    @request = request
    return unless request.status == "accepted"
    @requester = request.requester_profile
    @author = request.provocation_answer.submission
    mail(to: [ request.requester.email, request.recipient.email ],
      reply_to: [ request.requester.email, request.recipient.email ], subject: "Your Commonbound introduction")
  end
end
