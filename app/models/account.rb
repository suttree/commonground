class Account < ApplicationRecord
  has_many :submissions, dependent: :nullify
  has_many :challenges, through: :submissions
  # Keep a stable default for login and existing callers; dashboard selection is separate.
  has_one :submission, -> { order(Arel.sql("CASE kind WHEN 'person' THEN 0 ELSE 1 END"), :id) }
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }
end
