class LoginMailer < ApplicationMailer
  def code(email, code)
    mail(to: email, from: ENV.fetch("MAIL_FROM", "Commonbound <login@localhost>"), subject: "Your Commonbound login code") do |format|
      format.text { render plain: "Your Commonbound code is #{code}.\n\nIt expires in ten minutes and can only be used once.\nIf you didn't request this code, you can ignore this email." }
    end
  end
end
