class CollaboratorInvitation < ApplicationRecord
  belongs_to :challenge
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :expires_at, presence: true
  validate :no_existing_invitation, on: :create

  def no_existing_invitation
    existing = challenge.collaborator_invitations.where(email: email).where.not(id: id)
    if existing.where.not(accepted_at: nil).exists? || existing.where(revoked_at: nil).where("expires_at > ?", Time.current).exists?
      errors.add(:email, "already has an invitation. Cancel the pending invitation before sending another.")
    end
  end

  def available?
    accepted_at.nil? && revoked_at.nil? && expires_at > Time.current && challenge.public?
  end

  def status
    return "Accepted" if accepted_at
    return "Cancelled" if revoked_at
    return "Expired" if expires_at <= Time.current
    sent_at ? "Pending" : "Not sent"
  end

  def token
    signed_id(purpose: :collaborator_invitation, expires_at: expires_at)
  end

  def accept!(account)
    challenge.with_lock do
      reload
      return false unless available? && account.email == email
      profile = account.submission
      return false unless profile&.published? && profile.id != challenge.submission_id
      challenge.update!(collaborator_ids: (challenge.collaborator_ids.map(&:to_i) + [ profile.id ]).uniq)
      update!(accepted_at: Time.current)
    end
    true
  end
end
