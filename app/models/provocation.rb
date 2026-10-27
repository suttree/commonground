class Provocation < ApplicationRecord
  has_many :provocation_answers, dependent: :restrict_with_exception
  validates :key, :question, :position, presence: true
  validates :key, uniqueness: true
  validates :goal_id, inclusion: { in: ProfileOptions::GOALS.map { |goal| goal.fetch("id") } }
  validate :preserve_question, on: :update

  validates :status, inclusion: { in: %w[draft published retired] }
  validates :position, numericality: { only_integer: true }
  scope :published, -> { where(status: "published") }
  scope :visible, -> { where(status: %w[published retired]) }

  scope :in_order, -> { order(:position, :id) }

  def goal
    SdgDirectory.goal(goal_id)
  end

  private

  # A revised question needs a new record, even before its first answer.
  def preserve_question
    if status == "draft" && status_in_database != "draft"
      errors.add(:status, "cannot return to draft after publication")
    end
    if key_changed? || ((question_changed? || goal_id_changed?) && (status_in_database != "draft" || provocation_answers.exists?))
      errors.add(:base, "Create a new provocation to change its wording or goal")
    end
  end
end
