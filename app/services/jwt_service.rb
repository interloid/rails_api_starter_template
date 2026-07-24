class JwtService
  ACCESS_TTL = 15.minutes
  ALGORITHM = "HS256"

  class InvalidToken < StandardError; end

  # Opt-in access-token revocation. Access JWTs are stateless and valid for their full
  # TTL by default; enabling this checks a Rails.cache (Solid Cache) denylist on decode.
  DENYLIST_ENABLED = -> { ENV.fetch("JWT_DENYLIST_ENABLED", "false") == "true" }

  # Revoke a single access token by its jti until it would have expired anyway.
  def self.revoke_jti!(jti, exp)
    return unless DENYLIST_ENABLED.call
    ttl = exp.to_i - Time.current.to_i
    return if ttl <= 0
    Rails.cache.write("jwt:denylist:#{jti}", true, expires_in: ttl.seconds)
  end

  # Revoke ALL access tokens issued to a user before now (logout-everywhere,
  # password reset, compromise). Tokens carry iat, so a cutoff invalidates them all.
  def self.revoke_all_for!(user_id)
    return unless DENYLIST_ENABLED.call
    Rails.cache.write("jwt:cutoff:#{user_id}", Time.current.to_i, expires_in: ACCESS_TTL)
  end

  def self.revoked?(payload)
    return false unless DENYLIST_ENABLED.call
    return true if Rails.cache.read("jwt:denylist:#{payload['jti']}")
    cutoff = Rails.cache.read("jwt:cutoff:#{payload['sub']}")
    cutoff.present? && payload["iat"].to_i < cutoff.to_i
  end

  def self.secret
    Rails.application.credentials.dig(:jwt, :secret) ||
      raise("Missing jwt.secret in Rails credentials — run bin/rails credentials:edit")
  end

  def self.encode_access(user)
    now = Time.current.to_i
    JWT.encode({
      sub: user.id,
      jti: SecureRandom.uuid,
      iat: now,
      exp: ACCESS_TTL.from_now.to_i,
      type: "access"
    }, secret, ALGORITHM)
  end

  def self.decode(token)
    payload, = JWT.decode(token, secret, true, algorithm: ALGORITHM)
    raise InvalidToken, "wrong token type" unless payload["type"] == "access"
    raise InvalidToken, "token revoked" if revoked?(payload)
    payload
  rescue JWT::ExpiredSignature
    raise InvalidToken, "token expired"
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end
end
