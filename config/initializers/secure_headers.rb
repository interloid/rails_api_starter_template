# API returns JSON, not HTML, so browser-render protections are minimal by design.
# HSTS is intentionally OPT_OUT here — config.force_ssl (production) owns HSTS +
# the HTTP->HTTPS redirect, so there is a single source of truth and no duplicate header.
SecureHeaders::Configuration.default do |config|
  if Rails.env.development?
    # Relaxed so the dev-only Swagger UI can load its assets.
    config.csp = {
      default_src: [ "'self'" ],
      script_src:  [ "'self'", "'unsafe-inline'" ],
      style_src:   [ "'self'", "'unsafe-inline'" ],
      img_src:     [ "'self'", "data:" ],
      connect_src: [ "'self'" ]
    }
  else
    # default-src 'none' already blocks scripts; secure_headers 7.x refuses to let
    # script_src silently fall back to default-src, so opt it out explicitly. Net
    # emitted header stays "default-src 'none'".
    config.csp = { default_src: [ "'none'" ], script_src: SecureHeaders::OPT_OUT }
  end
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.referrer_policy = "no-referrer"
  config.x_permitted_cross_domain_policies = "none"
  config.hsts = SecureHeaders::OPT_OUT            # owned by config.force_ssl
  config.x_xss_protection = SecureHeaders::OPT_OUT # deprecated header, removed from browsers
end
