class Submission < ApplicationRecord
  belongs_to :account, optional: true
  validates :account_id, uniqueness: { conditions: -> { where(kind: "person") } }, allow_nil: true, if: -> { kind == "person" }

  KINDS = %w[person organisation].freeze
  WORKING_STYLES = [ "Figuring things out", "Improving something established", "Both" ].freeze
  ENGAGEMENTS = [ "Permanent role", "Freelance project", "Fractional / part-time", "Open to discussing" ].freeze
  STATUSES = [ "Received", "Needs a conversation", "Ready for introductions", "Introduced", "Outcome recorded" ].freeze
  PROFILE_FIELDS = %i[target_ids sectors_past sectors_future sector_reason radius_km education_topics satisfaction_feeling satisfaction_notes skills projects mission offering impact_metrics proud_of challenge_kind help_needed products].freeze

  CONTACT_ACTIONS = [ "Email me", "Follow me", "Connect on LinkedIn" ].freeze

  store_accessor :profile, *PROFILE_FIELDS, :exploring, :contact_action, :contact_destination, :skills_summary
  validate :valid_contact_action
  has_many :challenges, dependent: :destroy
  has_many :contact_requests, dependent: :destroy
  has_many :provocation_answers, dependent: :destroy
  has_many :side_projects, dependent: :destroy
  has_many :portfolio_images, dependent: :destroy
  has_one :profile_photo, dependent: :destroy
  attr_accessor :consent, :website_confirmation

  # Keep the original columns and their contents for applications already received.
  %i[purpose working_style engagement availability location pay_expectations].each do |field|
    attribute field, :string, default: ""
  end

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :name, :organisation_name, :website, with: ->(value) { value.strip }

  validates :kind, inclusion: { in: KINDS }
  validates :profile_version, inclusion: { in: [ 1, 2 ] }
  validates :name, :email, :purpose, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
  validates :name, :organisation_name, length: { maximum: 200 }
  validates :website, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z}, message: "must start with https:// or http://" }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }
  validates :purpose, :challenge, :experience, :availability, :location, :pay_expectations, length: { maximum: 5000 }
  validates :skills_summary, length: { maximum: 5000 }
  validates :notes, length: { maximum: 10000 }
  validates :organisation_name, :challenge, presence: true, if: :organisation?
  validates :experience, presence: true, unless: :organisation?
  validates :consent, acceptance: { accept: "1", allow_nil: false }, on: :create

  with_options unless: :structured_profile? do
    validates :working_style, :engagement, :availability, :location, :pay_expectations, presence: true
    validates :working_style, inclusion: { in: WORKING_STYLES }
    validates :engagement, inclusion: { in: ENGAGEMENTS }
  end

  with_options if: :structured_profile? do
    validates :mission, :offering, :challenge_kind, presence: true, if: -> { structured_profile? && organisation? }
    validates :challenge_kind, inclusion: { in: %w[Challenges Goals] }, allow_blank: true
    validates :satisfaction_feeling, inclusion: { in: ProfileOptions::FEELINGS }, allow_blank: true
    validates :radius_km, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 20000 }, allow_blank: true
    validates :location, presence: true, if: -> { radius_km.present? }
    validates :sector_reason, :education_topics, :satisfaction_notes, :mission, :offering, :impact_metrics, :proud_of, :help_needed, length: { maximum: 5000 }
    validate :valid_profile_choices
    validate :valid_repeated_entries
    validate :complete_satisfaction
    validate :valid_priorities
    validate :valid_project_details
  end

  before_validation :clean_profile_collections, if: :structured_profile?
  before_create { self.consented_at = Time.current }
  before_validation :assign_public_slug

  validates :public_slug, uniqueness: true, allow_nil: true
  validates :public_slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, allow_nil: true

  scope :published, -> { where(published: true) }

  def organisation?
    kind == "organisation"
  end

  def structured_profile?
    profile_version == 2
  end

  def display_name
    organisation? ? organisation_name : name
  end

  def profile_entries(field)
    value = public_send(field)
    value.is_a?(Array) ? value.select { |row| row.is_a?(Hash) } : []
  end

  def contact_link
    return if contact_action.blank? || contact_destination.blank?
    contact_action == "Email me" ? "mailto:#{contact_destination}" : contact_destination
  end

  def priorities_selected?
    Array(target_ids).any? || exploring == "1" || profile["quiz_completed_at"].present?
  end

  def save_quiz!(answers, targets: SdgQuiz.matches(answers).keys)
    update!(profile: profile.merge("quiz_answers" => answers, "quiz_completed_at" => Time.current.iso8601,
      "target_ids" => targets, "exploring" => targets.empty? ? "1" : "0"))
  end

  private

  def valid_contact_action
    return if contact_action.blank? && contact_destination.blank?
    errors.add(:contact_action, "must be selected") unless CONTACT_ACTIONS.include?(contact_action)
    destination = contact_destination.to_s
    valid = if contact_action == "Email me"
      destination.length <= 254 && destination.match?(URI::MailTo::EMAIL_REGEXP)
    else
      uri = URI.parse(destination)
      uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? &&
        (contact_action != "Connect on LinkedIn" || uri.host.downcase.match?(/\A(?:[a-z0-9-]+\.)*linkedin\.com\z/))
    end
    errors.add(:contact_destination, "must be a valid email address or full web address for your chosen action") unless valid && destination.length <= 500 && !destination.match?(/\s/)
  rescue URI::InvalidURIError
    errors.add(:contact_destination, "must be a valid full web address")
  end

  def valid_priorities
    errors.add(:exploring, "is invalid") unless [ nil, "", "0", "1" ].include?(exploring)
    changed = new_record? || profile.fetch("target_ids", nil) != (profile_in_database || {})["target_ids"] || exploring != (profile_in_database || {})["exploring"]
    return unless changed
    errors.add(:target_ids, "must contain no more than three current priorities") if Array(target_ids).size > 3
    errors.add(:target_ids, "must be cleared when you choose I'm still exploring") if exploring == "1" && Array(target_ids).any?
  end

  def valid_project_details
    profile_entries("projects").each_with_index do |row, index|
      ProfileOptions::PROJECT_DETAILS.each_key do |key|
        value = row[key]
        if (new_record? || row.key?(key)) && %w[title role].include?(key) && value.blank?
          errors.add(:projects, "entry #{index + 1}: #{ProfileOptions::PROJECT_DETAILS[key]} is required")
        elsif value.present? && (!value.is_a?(String) || value.length > 5000)
          errors.add(:projects, "entry #{index + 1}: #{key} is too long or invalid")
        end
      end
      if row["url"].present? && !row["url"].to_s.match?(%r{\Ahttps?://[^\s]+\z})
        errors.add(:projects, "entry #{index + 1}: project link must start with https:// or http://")
      end
    end
  end

  def assign_public_slug
    self.public_slug ||= "#{display_name.to_s.parameterize.presence || 'profile'}-#{SecureRandom.hex(6)}"
  end

  def clean_profile_collections
    %i[target_ids sectors_past sectors_future].each do |field|
      value = public_send(field)
      public_send("#{field}=", value.reject(&:blank?).uniq) if value.is_a?(Array)
    end
    ProfileOptions::REPEATED_FIELDS.each_key do |field|
      value = public_send(field)
      public_send("#{field}=", value.reject { |row| row.is_a?(Hash) && row.values.all?(&:blank?) }) if value.is_a?(Array)
    end
  end

  def valid_profile_choices
    { target_ids: ProfileOptions::TARGETS.keys, sectors_past: ProfileOptions::SECTORS, sectors_future: ProfileOptions::SECTORS }.each do |field, allowed|
      values = public_send(field)
      next if values.nil?
      errors.add(field, "contains an unknown choice") unless values.is_a?(Array) && values.all? { |value| allowed.include?(value) }
    end
  end

  def valid_repeated_entries
    ProfileOptions::REPEATED_FIELDS.each do |field, labels|
      rows = public_send(field)
      next if rows.nil?
      unless rows.is_a?(Array) && rows.size <= 10
        errors.add(field, "must contain no more than 10 entries")
        next
      end
      rows.each_with_index do |row, index|
        unless row.is_a?(Hash)
          errors.add(field, "entry #{index + 1} is invalid")
          next
        end
        labels.each do |key, label|
          value = row[key]
          if !value.is_a?(String) || value.blank?
            errors.add(field, "entry #{index + 1}: #{label} is required")
          elsif value.length > 5000
            errors.add(field, "entry #{index + 1}: #{label} is too long (maximum 5000 characters)")
          end
        end
      end
    end
  end

  def complete_satisfaction
    if satisfaction_notes.present? && satisfaction_feeling.blank?
      errors.add(:satisfaction_feeling, "must be chosen when you answer this section")
    elsif satisfaction_feeling.present? && satisfaction_notes.blank?
      errors.add(:satisfaction_notes, "can't be blank when you choose a feeling")
    end
  end
end
