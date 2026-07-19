require "socket"

class HealthController < ActionController::API
  # When this file exists, /health/ready reports "draining" (503) so the load balancer
  # pulls this instance BEFORE SIGTERM arrives. A preStop hook creates it (Section 14).
  # File-based (not a Ruby signal trap) to avoid conflicting with Puma's own handlers.
  SHUTDOWN_SENTINEL = ENV.fetch("SHUTDOWN_SENTINEL_PATH", Rails.root.join("tmp/shutdown").to_s)

  # GET /health/ready — readiness probe.
  # Fails (503) ONLY on critical dependencies that make this instance unable to
  # serve: database connectivity and pending migrations. Used by the load balancer
  # to pull the instance from rotation WITHOUT restarting it.
  def ready
    if File.exist?(SHUTDOWN_SENTINEL)
      return render json: {
        status: "draining", checks: {}, timestamp: Time.now.utc.iso8601
      }, status: :service_unavailable
    end

    checks = { database: database_ok?, migrations: migrations_ok? }
    ok = checks.values.all?
    render json: {
      status: ok ? "ready" : "not_ready",
      checks: checks,
      timestamp: Time.now.utc.iso8601
    }, status: ok ? :ok : :service_unavailable
  end

  # GET /health — detailed diagnostics.
  # Overall status reflects CRITICAL checks only (database + migrations). Cache is
  # reported but does not affect status (non-critical: misses fall through to DB).
  # The info block (commit, versions, uptime) is exposed in non-production always,
  # and in production ONLY with a valid X-Health-Token header.
  def show
    checks = {
      database:   database_ok?,
      migrations: migrations_ok?,
      cache:      cache_ok?
    }
    critical_ok = checks[:database] && checks[:migrations]

    body = {
      status: critical_ok ? "ok" : "error",
      checks: checks,
      timestamp: Time.now.utc.iso8601
    }
    body[:info] = info_payload if detailed_allowed?

    render json: body, status: critical_ok ? :ok : :service_unavailable
  end

  private

  def database_ok?
    ActiveRecord::Base.connection.select_value("SELECT 1") == 1
  rescue StandardError
    false
  end

  def migrations_ok?
    # Rails 8.1 removed AR::Base.connection.migration_context; the pool owns it now.
    !ActiveRecord::Base.connection_pool.migration_context.needs_migration?
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

  # Detail is public in non-prod; in prod it requires a matching token header.
  def detailed_allowed?
    return true unless Rails.env.production?

    expected = ENV["HEALTH_CHECK_TOKEN"].to_s
    return false if expected.empty?

    provided = request.headers["X-Health-Token"].to_s
    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def info_payload
    {
      app:            ENV.fetch("SERVICE_NAME", "rails_starter_template"),
      environment:    Rails.env,
      version:        ENV.fetch("APP_VERSION", "unknown"),
      commit:         app_revision,
      ruby:           RUBY_VERSION,
      rails:          Rails.version,
      uptime_seconds: uptime_seconds,
      hostname:       ENV["HOSTNAME"].presence || Socket.gethostname
    }
  end

  # Commit SHA cannot be read from git in a container (no .git). It is injected at
  # build time as GIT_SHA (Section 14 Docker), with a REVISION file fallback.
  def app_revision
    return ENV["GIT_SHA"] if ENV["GIT_SHA"].present?

    revision_file = Rails.root.join("REVISION")
    return File.read(revision_file).strip if File.exist?(revision_file)

    "unknown"
  end

  def uptime_seconds
    boot = Rails.application.config.x.boot_time
    boot ? (Time.current - boot).round : nil
  end
end
