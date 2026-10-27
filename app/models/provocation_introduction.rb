class ProvocationIntroduction < ApplicationRecord
  belongs_to :requester, class_name: "Account"
  belongs_to :recipient, class_name: "Account"
  belongs_to :provocation_answer
  validates :status, inclusion: { in: %w[pending accepted declined] }
  validates :recipient_id, uniqueness: { scope: :requester_id }
  validate :eligible_request, on: :create

  def available?
    status == "pending" && created_at > 30.days.ago &&
      provocation_answer.shared? && provocation_answer.allow_introductions? &&
      provocation_answer.note.present? && provocation_answer.submission.account_id == recipient_id &&
      requester.submissions.exists?(kind: "person")
  end

  def requester_profile
    requester.submissions.find_by(kind: "person")
  end

  private

  def eligible_request
    unless requester_id != recipient_id && requester_profile &&
        provocation_answer.shared? && provocation_answer.allow_introductions? &&
        provocation_answer.note.present? && provocation_answer.submission.account_id == recipient_id
      errors.add(:base, "This introduction is not available.")
    end
    if self.class.where(requester: requester).where("created_at > ?", 1.day.ago).count >= 5
      errors.add(:base, "You can request up to five introductions per day.")
    end
  end
end
