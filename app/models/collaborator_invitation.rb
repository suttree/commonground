class CollaboratorInvitation < ApplicationRecord
  belongs_to :challenge
  before_create { self.short_token = SecureRandom.urlsafe_base64(24) }
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :expires_at, presence: true
  validate :no_existing_invitation, on: :create

  def no_existing_invitation
    if Submission.where(id: challenge.collaborator_ids, email: email).exists?
      errors.add(:email, "already belongs to a collaborator on this project")
      return
    end
    existing = challenge.collaborator_invitations.where(email: email).where.not(id: id)
    if existing.where(accepted_at: nil, revoked_at: nil).where("expires_at > ?", Time.current).exists?
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
    short_token || signed_id(purpose: :collaborator_invitation, expires_at: expires_at)
  end

  def self.find_by_token(token)
    value = token.to_s
    invitation = if value.match?(/\A[A-Za-z0-9_-]{32}\z/)
      find_by(short_token: value)
    elsif value.length <= 512
      # Keep previously emailed signed links valid until their original expiry.
      find_signed(value, purpose: :collaborator_invitation)
    end
    invitation if invitation && invitation.expires_at > Time.current
  end

  def accept!(account, profile: account.submission)
    challenge.with_lock do
      reload
      return false unless available? && account.email == email
      return false unless profile&.published? && profile.account_id == account.id && profile.id != challenge.submission_id
      challenge.update!(collaborator_ids: (challenge.collaborator_ids.map(&:to_i) + [ profile.id ]).uniq)
      update!(accepted_at: Time.current)
    end
    true
  end
end
