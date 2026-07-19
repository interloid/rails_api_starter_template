require "swagger_helper"

RSpec.describe "Auth API", type: :request do
  path "/api/v1/auth/register" do
    post "Register a new account" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :registration, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string }, password: { type: :string },
          first_name: { type: :string }, last_name: { type: :string }
        },
        required: %w[email password]
      }

      response "201", "account created" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:registration) do
          { email: "new@example.com", password: "Password123!", first_name: "New", last_name: "User" }
        end
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["data"]["email"]).to eq("new@example.com")
        end
      end

      response "422", "validation failed (duplicate email)" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        before { create(:user, email: "dupe@example.com") }

        let(:registration) { { email: "dupe@example.com", password: "Password123!" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("validation_failed")
        end
      end
    end
  end

  path "/api/v1/auth/login" do
    post "Log in" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: { email: { type: :string }, password: { type: :string } },
        required: %w[email password]
      }

      response "200", "logged in" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:account) { create(:user, :confirmed, password: "Password123!") }
        let(:credentials) { { email: account.email, password: "Password123!" } }
        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data).to include("access_token", "refresh_token", "expires_in")
        end
      end

      response "401", "invalid credentials" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:account) { create(:user, password: "Password123!") }
        let(:credentials) { { email: account.email, password: "wrong" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("invalid_credentials")
        end
      end

      response "403", "account locked" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:account) { create(:user, :locked, password: "Password123!") }
        let(:credentials) { { email: account.email, password: "Password123!" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("account_locked")
        end
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Rotate the refresh token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :refresh_body, in: :body, schema: {
        type: :object,
        properties: { refresh_token: { type: :string } },
        required: %w[refresh_token]
      }

      response "200", "new token pair issued" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:account) { create(:user) }
        let(:raw_refresh) { RefreshToken.issue!(user: account).last }
        let(:refresh_body) { { refresh_token: raw_refresh } }
        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data).to include("access_token", "refresh_token")
        end
      end

      response "401", "invalid refresh token" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:refresh_body) { { refresh_token: "not-a-real-token" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("invalid_refresh_token")
        end
      end
    end
  end

  path "/api/v1/auth/logout" do
    post "Log out (revoke refresh tokens)" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: { refresh_token: { type: :string } },
        description: "Optional: provide to log out just this device; omit to log out everywhere."
      }

      response "200", "logged out" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:Authorization) { auth_header_for(create(:user)) }
        let(:body) { {} }
        run_test!
      end

      response "401", "unauthenticated" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:Authorization) { nil }
        let(:body) { {} }
        run_test!
      end
    end
  end

  path "/api/v1/auth/me" do
    get "Current user" do
      tags "Auth"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "current user returned" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:account) { create(:user) }
        let(:Authorization) { auth_header_for(account) }
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["id"]).to eq(account.id)
        end
      end

      response "401", "unauthenticated" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  # Non-documented side-effect check (ActiveJob adapter is :test).
  describe "registration side effects" do
    it "enqueues the confirmation email" do
      expect do
        post "/api/v1/auth/register",
             params: { email: "sideeffect@example.com", password: "Password123!" }.to_json,
             headers: { "Content-Type" => "application/json" }
      end.to have_enqueued_mail(UserMailer, :confirmation_email)
    end
  end
end
