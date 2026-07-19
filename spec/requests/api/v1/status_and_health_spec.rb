require "swagger_helper"

RSpec.describe "Status & Health", type: :request do
  path "/api/v1/status" do
    get "Service status (public)" do
      tags "Status"
      produces "application/json"

      response "200", "operational" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end
    end
  end

  path "/health" do
    get "Detailed health diagnostics" do
      tags "Health"
      produces "application/json"

      response "200", "healthy" do
        run_test! { |resp| expect(JSON.parse(resp.body)["status"]).to eq("ok") }
      end
    end
  end

  path "/health/ready" do
    get "Readiness probe" do
      tags "Health"
      produces "application/json"

      response "200", "ready" do
        run_test! { |resp| expect(JSON.parse(resp.body)["status"]).to eq("ready") }
      end
    end
  end

  path "/up" do
    get "Rails liveness probe" do
      tags "Health"

      response "200", "up" do
        run_test!
      end
    end
  end
end
