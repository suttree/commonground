namespace :emails do
  desc "Remind people whose collaborator invitation expires within a day. Run daily."
  task invitation_reminders: :environment do
    CollaboratorInvitation.where(accepted_at: nil, revoked_at: nil, reminded_at: nil).where.not(sent_at: nil)
      .where(expires_at: Time.current..1.day.from_now).find_each do |invitation|
      next unless invitation.available?
      CollaboratorInvitationMailer.reminder(invitation).deliver_now
      invitation.update!(reminded_at: Time.current)
    rescue StandardError => error
      Rails.logger.error("Invitation reminder failed: #{error.class.name}")
    end
  end
end
