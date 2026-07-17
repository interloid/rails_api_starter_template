class UserSerializer < ApplicationSerializer
  def serialize
    {
      id: record.id,
      email: record.email,
      first_name: record.first_name,
      last_name: record.last_name,
      full_name: record.full_name,
      roles: record.roles.map(&:name),
      created_at: record.created_at.utc.iso8601
    }
    # NOTE: password_digest is never exposed — explicit allowlist only.
  end
end
