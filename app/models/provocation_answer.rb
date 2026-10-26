class ProvocationAnswer < ApplicationRecord
  CHOICES = { "strong_no" => "Strong No", "no" => "No", "yes" => "Yes", "strong_yes" => "Strong Yes" }.freeze

  belongs_to :submission
  belongs_to :provocation
  validates :choice, inclusion: { in: CHOICES.keys }
  validates :provocation_id, uniqueness: { scope: :submission_id }

  def label
    CHOICES.fetch(choice)
  end
end
