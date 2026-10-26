require "marcel"

class ProfilePhoto < ApplicationRecord
  MAX_BYTES = 2.megabytes
  TYPES = %w[image/jpeg image/png image/webp].freeze
  belongs_to :submission, optional: true
  validates :content_type, inclusion: { in: TYPES }
  validates :data, :upload_owner, presence: true

  def self.stage(upload, owner, replacing: nil)
    message = "Choose a JPEG, PNG or WebP image up to 2 MB."
    raise ArgumentError, message unless upload.is_a?(ActionDispatch::Http::UploadedFile) && upload.size.between?(1, MAX_BYTES)
    type = Marcel::MimeType.for(upload.tempfile)
    raise ArgumentError, message unless TYPES.include?(type)
    where(submission_id: nil).where("created_at < ?", 24.hours.ago).delete_all
    if where(submission_id: nil, upload_owner: owner).where.not(id: replacing&.id).count >= 10
      raise ArgumentError, "You have too many unfinished photo uploads. Remove a draft photo before adding another."
    end
    create!(upload_owner: owner, content_type: type, data: upload.read)
  end

  def draft_token
    signed_id(purpose: "profile-photo:#{upload_owner}", expires_in: 24.hours)
  end
end
