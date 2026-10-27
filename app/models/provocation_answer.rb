class ProvocationAnswer < ApplicationRecord
  CHOICES = { "strong_no" => "Strong No", "no" => "No", "yes" => "Yes", "strong_yes" => "Strong Yes" }.freeze

  has_many :provocation_introductions, dependent: :destroy
  normalizes :note, with: ->(value) { value&.strip }
  validates :note, length: { maximum: 2000 }
  scope :shared, -> { where(shared: true) }
  scope :with_notes, -> { where.not(note: [ nil, "" ]) }

  belongs_to :submission
  belongs_to :provocation
  validates :choice, inclusion: { in: CHOICES.keys }
  validates :provocation_id, uniqueness: { scope: :submission_id }

  def label
    CHOICES.fetch(choice)
  end
end
