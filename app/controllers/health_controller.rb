class HealthController < ActionController::API
  # Database is critical: if it's down we return 503 so the load balancer pulls
  # this instance. Cache is reported for visibility but is non-critical.
  def show
    critical = { database: database_ok? }
    optional = { cache: cache_ok? }
    healthy  = critical.values.all?

    render json: {
      status: healthy ? "ok" : "error",
      checks: critical.merge(optional),
      timestamp: Time.now.utc.iso8601
    }, status: healthy ? :ok : :service_unavailable
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1
  rescue StandardError
    false
  end

  def cache_ok?
    key = "health_check:#{SecureRandom.hex(4)}"
    Rails.cache.write(key, "1", expires_in: 5.seconds)
    Rails.cache.read(key) == "1"
  rescue StandardError
    false
  end
end
