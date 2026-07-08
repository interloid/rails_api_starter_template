class AppConfig < Anyway::Config
  config_name :app

  attr_config(
    host: "localhost",
    port: 3000,
    max_threads: 5,
    log_level: "info"
  )

  required :host
  coerce_types port: :integer, max_threads: :integer
end
