class ContactRequest < ApplicationRecord
  OPTIONS = {
    "problem" => { label: "Pitch your problem", description: "Describe a problem you'd like help working through.", prompt: "What problem would you like to work on?" },
    "coffee" => { label: "Suggest a Zoom coffee chat", description: "Start with a conversation about a shared interest.", prompt: "What would you like to chat about?" },
    "services" => { label: "Request my services", description: "Share a brief for a project or piece of work.", prompt: "What help do you need? Include any timing or budget you have in mind." }
  }.freeze
  belongs_to :submission
  belongs_to :challenge, optional: true
  validate :challenge_recipient_matches

  def challenge_recipient_matches
    errors.add(:challenge, "must belong to the recipient") if challenge && challenge.submission_id != submission_id
  end
  attr_accessor :consent, :include_priorities, :website_confirmation
  normalizes :name, :email, with: ->(value) { value.strip }
  validates :intent, inclusion: { in: OPTIONS.keys }
  validates :name, :email, :message, presence: true
  validates :name, length: { maximum: 200 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :message, length: { maximum: 5000 }
  validates :consent, acceptance: { accept: "1", allow_nil: false }, on: :create
  before_create { self.consented_at = Time.current }
end
