module Api
  module V1
    class StatusController < BaseController
      allow_unauthenticated   # public health/status endpoint — no token required

      def show
        render_success(
          { service: ENV.fetch("SERVICE_NAME", "rails_api_starter_template"),
            version: "v1", environment: Rails.env },
          message: "API is operational"
        )
      end
    end
  end
end
