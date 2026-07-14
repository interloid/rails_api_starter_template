class User < ApplicationRecord
  include Discard::Model            # soft delete: .discard!, .kept, .discarded
  has_secure_password               # bcrypt; password_digest column

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :permissions, -> { distinct }, through: :roles

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  normalizes :email, with: ->(email) { email.strip.downcase }

  def full_name = [ first_name, last_name ].compact_blank.join(" ").presence

  # RBAC helpers (used by Section 8 authorization)
  def role?(name) = roles.exists?(name: name.to_s)
  def permission?(name) = permissions.exists?(name: name.to_s)
end
