# rswag-ui is a development-only gem (the docs UI is mounted only in development).
# Guard so this initializer is a no-op in test/production, where the constant is absent.
if defined?(Rswag::Ui)
  Rswag::Ui.configure do |c|
    c.openapi_endpoint "/api-docs/v1/swagger.yaml", "API V1 Docs"  # older rswag: c.swagger_endpoint
  end
end
