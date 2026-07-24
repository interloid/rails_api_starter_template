class User < ApplicationRecord
  include Discard::Model            # soft delete: .discard!, .kept, .discarded
  has_secure_password               # bcrypt; password_digest column

  MAX_FAILED_ATTEMPTS = 5
  LOCK_DURATION = 15.minutes

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :permissions, -> { distinct }, through: :roles
  # delete_all: the FK has no ON DELETE CASCADE, so a hard destroy must clear these
  # rows itself (opaque tokens carry no callbacks worth firing).
  has_many :refresh_tokens, dependent: :delete_all

  # Associations UserSerializer touches — use wherever a User is fetched for serialization.
  # (avatar_attachment: :blob rather than .with_attached_avatar, which would also pull
  # variant_records the serializer never reads and trip Bullet's unused-eager-load check.)
  scope :for_serialization, -> { includes(:roles, avatar_attachment: :blob) }

  has_one_attached :avatar

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # Validated BEFORE commit (active_storage_validations) so a bad upload never leaves
  # an orphaned blob behind.
  validates :avatar,
            content_type: { in: %w[image/png image/jpeg image/webp],
                            message: "must be a PNG, JPEG, or WebP image" },
            size: { less_than: 5.megabytes, message: "must be smaller than 5MB" }

  normalizes :email, with: ->(email) { email.strip.downcase }

  # Discarding a user must terminate their sessions — otherwise their refresh tokens
  # remain usable even though authentication rejects them.
  after_discard do
    refresh_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
  end

  # Password reset: token dies as soon as the password changes.
  generates_token_for :password_reset, expires_in: 30.minutes do
    password_salt&.last(10)
  end

  # Email confirmation: token dies once the account is confirmed.
  generates_token_for :email_confirmation, expires_in: 24.hours do
    confirmed_at&.to_i
  end

  def full_name = [ first_name, last_name ].compact_blank.join(" ").presence

  # RBAC helpers (used by Section 8 authorization)
  def role?(name) = roles.exists?(name: name.to_s)

  # Memoized per request/instance — avoids N queries when several permissions are checked.
  def permission_names
    @permission_names ||= permissions.pluck(:name)
  end

  def permission?(name) = permission_names.include?(name.to_s)

  # Confirmable
  def confirmed? = confirmed_at.present?
  def confirm! = update!(confirmed_at: Time.current)

  # Lockable
  def locked? = locked_at.present? && locked_at > LOCK_DURATION.ago

  def register_failed_attempt!
    # A previously expired lock starts a FRESH window — otherwise one failure after
    # expiry immediately re-locks (counter was never reset).
    reset_failed_attempts! if locked_at.present? && !locked?

    # Never extend an ACTIVE lock — otherwise an attacker can keep an account locked
    # indefinitely by retrying every LOCK_DURATION.
    return if locked?

    increment!(:failed_attempts)
    update!(locked_at: Time.current) if failed_attempts >= MAX_FAILED_ATTEMPTS
  end

  def reset_failed_attempts! = update!(failed_attempts: 0, locked_at: nil)

  # Trackable
  def track_sign_in!(ip)
    update!(
      sign_in_count: sign_in_count + 1,
      last_sign_in_at: current_sign_in_at,
      last_sign_in_ip: current_sign_in_ip,
      current_sign_in_at: Time.current,
      current_sign_in_ip: ip
    )
  end
end
