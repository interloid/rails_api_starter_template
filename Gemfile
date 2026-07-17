source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Typed, validated configuration over credentials + ENV
gem "anyway_config", "~> 2.0"
# Structured JSON request logging to stdout
gem "lograge"
# Application performance monitoring (inert unless NEW_RELIC_LICENSE_KEY is set)
gem "newrelic_rpm"
# Security response headers (Helmet equivalent)
gem "secure_headers"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# File uploads via Active Storage + S3.
gem "aws-sdk-s3", require: false          # S3 service backend
gem "active_storage_validations"          # validate content-type/size BEFORE commit (avoids orphan blobs)

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# Pagination
gem "pagy"

# Soft delete (discarded_at)
gem "discard", "~> 1.4"

# JSON Web Tokens for stateless access tokens
gem "jwt"

# Minimal authorization / RBAC policies
gem "pundit"

# OpenAPI/Swagger docs (rswag-specs — spec-driven generation — added in Section 13 with RSpec)
gem "rswag-api"
gem "rswag-ui"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Detect N+1 queries and unused eager loading [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # Auto-load machine-local env vars from .env* files (dev/test only, never prod)
  gem "dotenv-rails"
end

group :development do
  # Web dashboard for Solid Queue (jobs, workers, failed jobs), mounted at /jobs.
  # Dev-only: it needs an asset pipeline (propshaft + importmap), which this API-only
  # app otherwise omits — keeping it here keeps production lean. Prod gating: Section 14.
  gem "mission_control-jobs"
  gem "propshaft"
  gem "importmap-rails"

  # Detect unreachable and unused routes [https://github.com/amatsuda/traceroute]
  gem "traceroute", require: false

  # Static analysis code quality report [https://github.com/whitesmith/rubycritic]
  gem "rubycritic", require: false

  # Git hooks manager [https://github.com/evilmartians/lefthook]
  gem "lefthook", require: false
end

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
group :rubocop do
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-minitest", require: false
end
