class SideProject < ApplicationRecord
  belongs_to :submission
  has_many :photos, -> { order(:id) }, class_name: "PortfolioImage", dependent: :destroy
  validates :name, presence: true, length: { maximum: 200 }
  validates :description, :purpose, :joy, length: { maximum: 5000 }
  validates :url, length: { maximum: 500 }, format: { with: %r{\Ahttps?://[^\s]+\z}, message: "must start with https:// or http://" }, allow_blank: true
  validate :personal_profile
  validate :project_limit, on: :create

  def cover_photo
    photos.detect { |photo| photo.id == cover_image_id } || photos.first
  end

  private

  def personal_profile
    errors.add(:submission, "must be a personal profile") if submission&.organisation?
  end

  def project_limit
    errors.add(:base, "You can add up to 10 side projects.") if submission && submission.side_projects.count >= 10
  end
end
