class User < ApplicationRecord
  include Discard::Model            # soft delete: .discard!, .kept, .discarded
  has_secure_password               # bcrypt; password_digest column

  MAX_FAILED_ATTEMPTS = 5
  LOCK_DURATION = 15.minutes

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :permissions, -> { distinct }, through: :roles

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
