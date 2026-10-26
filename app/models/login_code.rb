class LoginCode < ApplicationRecord
  def self.issue(email, ip)
    transaction do
      recent = where(created_at: 10.minutes.ago..)
      return if recent.where(email: email).count >= 3 || recent.where(request_ip: ip).count >= 20
      code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
      challenge = create!(email: email, request_ip: ip, digest: "pending", expires_at: 10.minutes.from_now)
      challenge.update!(digest: challenge.code_digest(code))
      [ challenge, code ]
    end
  end

  def consume(code)
    with_lock do
      return false if used_at || expires_at <= Time.current || attempts >= 5
      update!(attempts: attempts + 1)
      return false unless code.to_s.match?(/\A\d{6}\z/) && ActiveSupport::SecurityUtils.secure_compare(digest, code_digest(code))
      update!(used_at: Time.current)
      true
    end
  end

  def code_digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "login:#{id}:#{code}")
  end
end
