class JwtService
  ACCESS_TTL = 15.minutes
  ALGORITHM = "HS256"

  class InvalidToken < StandardError; end

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
    payload
  rescue JWT::ExpiredSignature
    raise InvalidToken, "token expired"
  rescue JWT::DecodeError => e
    raise InvalidToken, e.message
  end
end
