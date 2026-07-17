class RefreshToken < ApplicationRecord
  EXPIRY = 7.days

  belongs_to :user

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # Issues a new opaque token. Returns [record, raw_token]; the raw token is shown
  # to the client exactly once and never stored.
  def self.issue!(user:, family_id: nil, user_agent: nil, ip_address: nil)
    raw = SecureRandom.urlsafe_base64(48)
    record = create!(
      user: user,
      token_digest: digest(raw),
      family_id: family_id || SecureRandom.uuid,
      expires_at: EXPIRY.from_now,
      user_agent: user_agent,
      ip_address: ip_address
    )
    [ record, raw ]
  end

  def self.digest(raw) = Digest::SHA256.hexdigest(raw)
  def self.find_by_raw(raw) = find_by(token_digest: digest(raw))

  def active? = revoked_at.nil? && expires_at > Time.current
  def revoke! = update!(revoked_at: Time.current)

  # Reuse detected: kill the entire lineage, not just this token.
  def revoke_family!
    self.class.where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.current)
  end
end
