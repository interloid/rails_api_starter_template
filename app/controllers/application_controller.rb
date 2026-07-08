class ApplicationController < ActionController::API
  before_action :set_correlation_id

  private

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
