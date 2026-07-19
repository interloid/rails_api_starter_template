# rswag-api is a development-only gem (the docs engine is mounted only in development).
# Guard so this initializer is a no-op in test/production, where the constant is absent.
if defined?(Rswag::Api)
  Rswag::Api.configure do |c|
    c.openapi_root = Rails.root.join("swagger").to_s   # older rswag: c.swagger_root
  end
end
