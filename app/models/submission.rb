class Submission < ApplicationRecord
  KINDS = %w[person organisation].freeze
  WORKING_STYLES = [ "Figuring things out", "Improving something established", "Both" ].freeze
  ENGAGEMENTS = [ "Permanent role", "Freelance project", "Fractional / part-time", "Open to discussing" ].freeze
  STATUSES = [ "Received", "Needs a conversation", "Ready for introductions", "Introduced", "Outcome recorded" ].freeze

  attr_accessor :consent, :website_confirmation

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :name, :organisation_name, :website, with: ->(value) { value.strip }

  validates :kind, inclusion: { in: KINDS }
  validates :name, :email, :purpose, :working_style, :engagement, :availability, :location, :pay_expectations, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :name, :organisation_name, length: { maximum: 200 }
  validates :website, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z}, message: "must start with https:// or http://" }, allow_blank: true
  validates :working_style, inclusion: { in: WORKING_STYLES }
  validates :engagement, inclusion: { in: ENGAGEMENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :purpose, :challenge, :experience, :availability, :location, :pay_expectations, length: { maximum: 5000 }
  validates :notes, length: { maximum: 10000 }
  validates :organisation_name, :challenge, presence: true, if: :organisation?
  validates :experience, presence: true, unless: :organisation?
  validates :consent, acceptance: { accept: "1", allow_nil: false }, on: :create

  before_create { self.consented_at = Time.current }

  def organisation?
    kind == "organisation"
  end

  def display_name
    organisation? ? organisation_name : name
  end
end
