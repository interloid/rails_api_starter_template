# Origins come from the CORS_ORIGINS env var (comma-separated).
# Dev: falls back to localhost origins if unset.
# Production: empty => NO cross-origin allowed (fail closed). Set CORS_ORIGINS to enable.
cors_origins = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
if cors_origins.empty? && !Rails.env.production?
  cors_origins = %w[http://localhost:3000 http://localhost:5173]
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*cors_origins)
    resource "*",
      headers: :any,
      expose: [ "Authorization" ],                      # so clients can read the JWT (Section 8)
      methods: %i[get post put patch delete options head],
      credentials: false                              # token auth via header, not cookies
  end
end
