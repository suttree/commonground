class Challenge < ApplicationRecord
  STATUSES = %w[draft active completed paused abandoned].freeze
  HELP_OPTIONS = [ "Private funding", "Public subsidy", "Sales", "Media coverage", "Hiring" ].freeze
  belongs_to :submission
  belongs_to :organisation, class_name: "Submission", optional: true
  has_many :contact_requests, dependent: :nullify
  has_many :collaborator_invitations, dependent: :destroy

  normalizes :title, :organisation_name, :industry, :location, :project_role, :project_url, with: ->(value) { value.strip }
  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :organisation_name, :location, :project_role, length: { maximum: 200 }
  validates :description, :objectives, :target, :context, :approach, :results, length: { maximum: 5000 }
  validates :industry, inclusion: { in: ProfileOptions::SECTORS }, allow_blank: true
  validates :description, :location, :objectives, presence: true, unless: -> { status == "draft" }
  validates :project_role, :context, :approach, :results, presence: true, if: -> { status == "completed" }
  validates :project_url, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z} }, allow_blank: true
  validate :single_active_challenge
  validate :valid_project_url
  validate :valid_collections
  validate :valid_organisation
  before_validation :retain_organisation_name
  before_validation :clean_collections
  before_save :record_dates

  scope :publicly_visible, -> { joins(:submission).merge(Submission.published).where.not(status: "draft").where.not(published_at: nil) }
  scope :discoverable, -> { publicly_visible.where(status: %w[active completed]) }
  scope :recent, -> { order(published_at: :desc, id: :desc) }

  def public?
    submission.published? && status != "draft" && published_at.present?
  end

  def completed?
    status == "completed"
  end

  def validated_project_url
    uri = URI.parse(project_url.to_s)
    uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end

  def collaborators
    Submission.published.where(id: collaborator_ids).order(:name)
  end

  def public_organisation
    return organisation if organisation&.organisation? && organisation.published?
    submission if organisation_id.nil? && organisation_name.blank? && submission.organisation? && submission.published?
  end

  def on_behalf_of_name
    public_organisation&.display_name || organisation_name.presence
  end

  def self.filtered(filters)
    records = all
    if filters[:q].present?
      term = "%#{sanitize_sql_like(filters[:q])}%"
      records = records.where("challenges.title LIKE ? OR challenges.description LIKE ?", term, term)
    end
    records = records.where("challenges.location LIKE ?", "%#{sanitize_sql_like(filters[:location])}%") if filters[:location].present?
    records = records.where(industry: filters[:industry]) if filters[:industry].present?
    records = records.where(status: filters[:status]) if filters[:status].present?
    if filters[:goal].present?
      records = records.where("EXISTS (SELECT 1 FROM json_each(challenges.target_ids) WHERE value LIKE ?)", "#{sanitize_sql_like(filters[:goal])}.%")
    end
    records
  end

  private

  def valid_organisation
    return if organisation_id.nil? || (persisted? && !organisation_id_changed?)
    unless organisation&.organisation? && organisation.published?
      errors.add(:organisation, "must be a public company profile")
    end
  end

  def retain_organisation_name
    self.organisation_name = organisation.display_name if organisation&.organisation? && organisation.published?
  end

  def single_active_challenge
    if status == "active" && submission && submission.challenges.where(status: "active").where.not(id: id).exists?
      errors.add(:base, "You already have an active challenge. Update its status before publishing another.")
    end
  end

  def valid_project_url
    errors.add(:project_url, "must be a full http:// or https:// address") if project_url.present? && validated_project_url.nil?
  end

  def clean_collections
    %w[help_options target_ids collaborator_ids].each do |field|
      values = public_send(field)
      next unless values.is_a?(Array)
      values = values.reject(&:blank?).uniq
      public_send("#{field}=", values)
    end
  end

  def valid_collections
    { help_options: HELP_OPTIONS, target_ids: ProfileOptions::TARGETS.keys }.each do |field, allowed|
      values = public_send(field)
      errors.add(field, "contains an unknown choice") unless values.is_a?(Array) && values.all? { |value| allowed.include?(value) }
    end
    errors.add(:target_ids, "must contain no more than three priorities") if target_ids.is_a?(Array) && target_ids.size > 3
    unless collaborator_ids.is_a?(Array) && collaborator_ids.size <= 20 && collaborator_ids.all? { |id| id.to_s.match?(/\A[1-9][0-9]*\z/) }
      errors.add(:collaborator_ids, "must contain up to 20 member profiles")
      return
    end
    ids = collaborator_ids.map(&:to_i).uniq
    # Existing links can remain in an owner's draft if a member later unpublishes;
    # the public view always excludes unpublished members.
    existing_ids = Array(collaborator_ids_in_database).map(&:to_i)
    added_ids = ids - existing_ids
    if ids.include?(submission_id) || Submission.published.where(id: added_ids).count != added_ids.size
      errors.add(:collaborator_ids, "must refer to other public member profiles")
    end
  end

  def record_dates
    self.published_at ||= Time.current if status != "draft"
    self.completed_at = status == "completed" ? (completed_at || Time.current) : nil
  end
end
