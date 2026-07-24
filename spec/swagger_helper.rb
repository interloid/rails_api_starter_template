# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.3",
      info: {
        title: "Rails API Starter Template",
        version: "v1",
        description: "API documentation. All responses use a consistent envelope."
      },
      servers: [ { url: "http://localhost:3000", description: "Development" } ],
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        },
        schemas: {
          SuccessResponse: {
            type: :object,
            properties: {
              success: { type: :boolean, example: true },
              status_code: { type: :integer, example: 200 },
              message: { type: :string },
              # Payload is polymorphic: an object (show/login), an array (index), or null
              # (logout). Left type-agnostic so the one shared envelope validates them all.
              data: { nullable: true, description: "Response payload (object, array, or null)." },
              pagination_meta: {
                type: :object, nullable: true,
                properties: {
                  total: { type: :integer }, page: { type: :integer },
                  records_per_page: { type: :integer }, total_pages: { type: :integer }
                }
              },
              meta_data: { type: :object, nullable: true },
              timestamp: { type: :string, format: :"date-time" },
              path: { type: :string }
            }
          },
          ErrorResponse: {
            type: :object,
            properties: {
              success: { type: :boolean, example: false },
              status_code: { type: :integer, example: 422 },
              error_code: { type: :string, example: "validation_failed" },
              message: { type: :string },
              errors: {
                type: :array,
                items: {
                  type: :object,
                  properties: { field: { type: :string, nullable: true }, message: { type: :string } }
                }
              },
              correlation_id: { type: :string, nullable: true },
              timestamp: { type: :string, format: :"date-time" },
              path: { type: :string }
            }
          }
        }
      }
    }
  }
  config.openapi_format = :yaml
end
