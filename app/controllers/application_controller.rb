# CSRF protection is intentionally absent. ActionController::API does not include it
# (it lives only in ActionController::Base), and CSRF is a cookie-session attack —
# irrelevant to this stateless token API, where the credential is an Authorization
# header that browsers never auto-attach cross-site. This is a deliberate decision.
class ApplicationController < ActionController::API
  # Global per-IP rate limit (defense-in-depth). Env-tunable; tighten per-controller
  # for sensitive endpoints (auth gets a stricter limit in Section 8). /health and /up
  # are exempt because HealthController inherits ActionController::API directly.
  # NOTE: backed by Rails.cache — effective in production via Solid Cache (Section 9),
  # works in dev with `bin/rails dev:cache`, and safely no-ops under the null store.
  rate_limit to:     ENV.fetch("RATE_LIMIT_REQUESTS", 300).to_i,
             within:  ENV.fetch("RATE_LIMIT_WITHIN_SECONDS", 60).to_i.seconds,
             by:      -> { request.remote_ip },
             with:    -> { render_rate_limited },
             scope:   "global"

  before_action :set_correlation_id

  private

  def render_rate_limited
    render json: {
      error: { code: "rate_limited", message: "Too many requests. Please retry later." }
    }, status: :too_many_requests
  end

  # Cross-service trace id: honor an inbound correlation/request id from an
  # upstream gateway or client; fall back to Rails' own per-request UUID.
  def correlation_id
    @correlation_id ||=
      request.headers["X-Correlation-ID"].presence ||
      request.headers["X-Request-ID"].presence ||
      request.request_id
  end

  def set_correlation_id
    # Echo it back so clients can quote it in bug reports / support tickets.
    response.set_header("X-Correlation-ID", correlation_id)
    # Link logs <-> New Relic APM (no-op while the agent is inert).
    if defined?(::NewRelic)
      ::NewRelic::Agent.add_custom_attributes(correlation_id: correlation_id)
    end
  end

  # Feeds fields into the lograge payload (read back in custom_options above).
  def append_info_to_payload(payload)
    super
    payload[:correlation_id] = correlation_id
    payload[:request_id]     = request.request_id
    payload[:remote_ip]      = request.remote_ip
    payload[:user_agent]     = request.user_agent
    payload[:host]           = request.host
    # Guarded: current_user doesn't exist until Section 8 (auth). This starts
    # populating automatically once the auth concern defines current_user.
    payload[:user_id]        = current_user&.id if respond_to?(:current_user, true)
  end
end
