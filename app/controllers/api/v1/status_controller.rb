module Api
  module V1
    class StatusController < BaseController
      allow_unauthenticated   # public health/status endpoint — no token required
      # Public status has no record to authorize.
      skip_after_action :verify_authorized, raise: false

      def show
        render_success(
          { service: ENV.fetch("SERVICE_NAME", "rails_starter_template"),
            version: "v1", environment: Rails.env },
          message: "API is operational"
        )
      end
    end
  end
end
