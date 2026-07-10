# config/initializers/00_config.rb
# Validate typed app config and expose it as Rails.configuration.app.
# to_prepare runs at boot (fail-fast on invalid config) and after each reload,
# which is Rails' recommended way to reference reloadable app/ classes at boot.
Rails.application.config.to_prepare do
  Rails.application.config.app = AppConfig.new
end
