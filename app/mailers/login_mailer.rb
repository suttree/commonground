class LoginMailer < ApplicationMailer
  def code(email, code)
    @code = code
    mail(to: email, from: ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>"), subject: "Let’s Commonbound to faster solutions.")
  end
end
