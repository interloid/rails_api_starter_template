require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on S3 (see config/storage.yml → amazon).
  config.active_storage.service = :amazon
  # Signed blob URLs (and direct-upload URLs) expire after this window.
  config.active_storage.urls_expire_in = 10.minutes

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Required so Rails trusts X-Forwarded-Proto behind a TLS-terminating load balancer.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Owns HSTS + the HTTP->HTTPS redirect (secure_headers opts out of HSTS to avoid duplication).
  # Default ON. Set FORCE_SSL=false for local container testing, or on platforms that
  # terminate TLS upstream and don't want a double redirect.
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  # Skip the http->https redirect for health probes: load balancers hit these over
  # plain HTTP internally, and a 301 would make them mark the instance unhealthy.
  config.ssl_options = {
    redirect: {
      exclude: ->(request) { request.path == "/up" || request.path.start_with?("/health") }
    }
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Emit structured JSON request logs (backend-agnostic, no New Relic coupling).
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  # CRITICAL for API-only: controllers inherit ActionController::API, not ::Base;
  # without this, lograge silently logs nothing.
  config.lograge.base_controller_class = "ActionController::API"

  # lograge already emits: method, path, format, controller, action, status,
  # duration, db, view. custom_options ADDS to that — do not duplicate those.
  config.lograge.custom_options = lambda do |event|
    payload = event.payload
    data = {
      time:           Time.now.utc.iso8601,
      service:        ENV.fetch("SERVICE_NAME", "rails_starter_template"),
      env:            Rails.env,
      correlation_id: payload[:correlation_id],
      request_id:     payload[:request_id],
      remote_ip:      payload[:remote_ip],
      user_agent:     payload[:user_agent],
      host:           payload[:host],
      user_id:        payload[:user_id]
    }
    if (exception = payload[:exception])
      data[:exception]         = exception.first
      data[:exception_message] = exception.last
    end
    # Opt-in filtered params (redacted via Rails' filter_parameters). Leave OFF
    # by default; uncomment if you need request bodies in logs:
    # data[:params] = event.payload[:params]&.except("controller", "action")
    data
  end

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # Single-DB topology (Section 9): do NOT set solid_queue.connects_to — with one
  # database, Solid Queue uses the primary connection. Add connects_to only if you
  # later split the queue onto its own database.
  config.active_job.queue_adapter = :solid_queue

  # Absolute URLs in emails need a real public host (a localhost default would
  # produce dead links). Provided via ENV so the template isn't provider-locked.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "localhost"),
    protocol: "https"
  }
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  # Inert unless SMTP credentials exist — the app boots fine without them.
  if Rails.application.credentials.smtp.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: Rails.application.credentials.smtp[:user_name],
      password: Rails.application.credentials.smtp[:password],
      authentication: "plain",
      enable_starttls_auto: true
    }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and block Host-header injection.
  # Comma-separated allowed hosts (e.g. "api.example.com,www.example.com").
  allowed = ENV.fetch("ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  config.hosts.concat(allowed) if allowed.any?
  # Always allow health-check probes (load balancers hit these by IP/internal host):
  config.host_authorization = {
    exclude: ->(request) { request.path == "/up" || request.path.start_with?("/health") }
  }
end
