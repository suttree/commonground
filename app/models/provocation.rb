class Provocation < ApplicationRecord
  has_many :provocation_answers, dependent: :restrict_with_exception
  validates :key, :question, :position, presence: true
  validates :key, uniqueness: true
  validates :goal_id, inclusion: { in: ProfileOptions::GOALS.map { |goal| goal.fetch("id") } }
  validate :preserve_question, on: :update

  scope :in_order, -> { order(:position, :id) }

  def goal
    SdgDirectory.goal(goal_id)
  end

  private

  # A revised question needs a new record, even before its first answer.
  def preserve_question
    if question_changed? || goal_id_changed? || key_changed?
      errors.add(:base, "Create a new provocation to change its wording or goal")
    end
  end
end
