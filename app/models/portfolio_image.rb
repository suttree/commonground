require "marcel"

class PortfolioImage < ApplicationRecord
  MAX_BYTES = 2.megabytes
  TYPES = %w[image/jpeg image/png image/webp].freeze
  belongs_to :submission, optional: true
  belongs_to :side_project, optional: true
  validates :content_type, inclusion: { in: TYPES }
  validates :data, :upload_owner, presence: true

  def self.stage(upload, owner, replacing: nil)
    raise ArgumentError, "Choose a JPEG, PNG or WebP image under 2 MB." unless upload.is_a?(ActionDispatch::Http::UploadedFile) && upload.size.between?(1, MAX_BYTES)
    type = Marcel::MimeType.for(upload.tempfile)
    raise ArgumentError, "Choose a JPEG, PNG or WebP image under 2 MB." unless TYPES.include?(type)
    where(submission_id: nil).where("created_at < ?", 24.hours.ago).delete_all
    raise ArgumentError, "You can keep up to 10 images in a draft. Remove an image before adding another." if where(submission_id: nil, upload_owner: owner).where.not(id: replacing&.id).count >= 10
    create!(upload_owner: owner, content_type: type, data: upload.read)
  end

  def draft_token
    signed_id(purpose: "portfolio:#{upload_owner}", expires_in: 24.hours)
  end
end
